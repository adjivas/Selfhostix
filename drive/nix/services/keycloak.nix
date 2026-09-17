{
  config,
  lib,
  pkgs,
  ...
}: {
  options.drive.keycloak.databasePassword = lib.mkOption {
    type = lib.types.str;
    default = "keycloak";
    description = "Password used by Keycloak to connect to PostgreSQL.";
  };

  config = {
    services.postgresql = {
      ensureDatabases = ["keycloak"];

      ensureUsers = [
        {
          name = "keycloak";
          ensureDBOwnership = true;
          ensureClauses.password = config.drive.keycloak.databasePassword;
        }
      ];

      authentication = ''
        host keycloak keycloak 127.0.0.1/32 scram-sha-256
      '';
    };

    services.keycloak = {
      enable = true;
      initialAdminPassword = "admin";

      database = {
        type = "postgresql";
        host = "127.0.0.1";
        port = 5432;
        name = "keycloak";
        username = "keycloak";
        passwordFile = "/run/keycloak-db-password";
        useSSL = false;
      };

      settings = {
        hostname = "https://auth.drive";
        http-enabled = true;
        http-host = "127.0.0.1";
        http-port = 8080;
        proxy-headers = "xforwarded";
      };
    };

    systemd.services.keycloak-credentials-db = {
      description = "Prepare Keycloak database credentials";
      before = ["keycloak.service"];
      requiredBy = ["keycloak.service"];

      serviceConfig.Type = "oneshot";

      script = ''
        install -D -m 0600 /dev/null /run/keycloak-db-password
        printf '%s' ${lib.escapeShellArg config.drive.keycloak.databasePassword} > /run/keycloak-db-password
      '';
    };

    systemd.services.keycloak = {
      after = ["postgresql.target"];
      requires = ["postgresql.target"];
    };

    systemd.services.keycloak-provision = {
      description = "Provision Keycloak for La Suite Drive";
      after = ["keycloak.service"];
      requires = ["keycloak.service"];
      before = ["keycloak-credentials.service"];
      wants = ["keycloak-credentials.service"];
      wantedBy = ["multi-user.target"];

      path = [
        config.services.keycloak.package
        pkgs.gnugrep
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -eu

        kcadm.sh config credentials \
          --server http://127.0.0.1:8080 \
          --realm master \
          --user admin \
          --password ${lib.escapeShellArg config.services.keycloak.initialAdminPassword}

        if ! kcadm.sh get realms/drive >/dev/null 2>&1; then
          kcadm.sh create realms -s realm=drive -s enabled=true
        fi

        client_id="$(kcadm.sh get clients -r drive -q clientId=drive --fields id --format csv --noquotes)"

        if [ -z "$client_id" ]; then
          kcadm.sh create clients -r drive \
            -s clientId=drive \
            -s enabled=true \
            -s publicClient=false \
            -s standardFlowEnabled=true \
            -s directAccessGrantsEnabled=false \
            -s 'redirectUris=["https://drive/api/v1.0/callback/"]' \
            -s 'webOrigins=["https://drive"]'
        else
          kcadm.sh update "clients/$client_id" -r drive \
            -s enabled=true \
            -s publicClient=false \
            -s standardFlowEnabled=true \
            -s directAccessGrantsEnabled=false \
            -s 'redirectUris=["https://drive/api/v1.0/callback/"]' \
            -s 'webOrigins=["https://drive"]'
        fi

        if ! kcadm.sh get users -r drive -q username=drive | grep -q '"username" : "drive"'; then
          kcadm.sh create users -r drive \
            -s username=drive \
            -s enabled=true \
            -s email=drive@example.test \
            -s emailVerified=true \
            -s firstName=Drive \
            -s lastName=User

          kcadm.sh set-password -r drive --username drive --new-password drive
        fi
      '';
    };

    systemd.services.keycloak-credentials = {
      description = "Export Keycloak credentials for La Suite Drive";
      after = ["keycloak-provision.service"];
      requires = ["keycloak-provision.service"];
      before = [
        "lasuite-drive.service"
        "lasuite-drive-celery.service"
        "lasuite-drive-beat.service"
      ];

      wantedBy = [
        "lasuite-drive.service"
        "lasuite-drive-celery.service"
        "lasuite-drive-beat.service"
      ];

      path = [config.services.keycloak.package];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "keycloak-credentials";
        RuntimeDirectoryMode = "0700";
      };

      script = ''
        set -eu

        kcadm.sh config credentials \
          --server http://127.0.0.1:8080 \
          --realm master \
          --user admin \
          --password ${lib.escapeShellArg config.services.keycloak.initialAdminPassword}

        client_id="$(kcadm.sh get clients -r drive -q clientId=drive --fields id --format csv --noquotes)"
        client_secret="$(
          kcadm.sh get "clients/$client_id/client-secret" -r drive --fields value --format csv --noquotes
        )"

        cat > /run/keycloak-credentials/drive.env <<EOF
        OIDC_RP_CLIENT_SECRET=$client_secret
        EOF

        chmod 600 /run/keycloak-credentials/drive.env
      '';
    };
  };
}

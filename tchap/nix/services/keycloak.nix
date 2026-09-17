{
  config,
  lib,
  ...
}: {
  options.tchap.keycloak.databasePassword = lib.mkOption {
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
          ensureClauses.password = config.tchap.keycloak.databasePassword;
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

      realmFiles = [
        ../keycloak/proconnect-mock-realm.json
      ];

      settings = {
        hostname = "https://auth.tchap";
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
        printf '%s' ${lib.escapeShellArg config.tchap.keycloak.databasePassword} \
          > /run/keycloak-db-password
      '';
    };

    systemd.services.keycloak = {
      after = ["postgresql.target"];
      requires = ["postgresql.target"];
    };

    systemd.services.keycloak-provision = {
      description = "Provision Tchap Keycloak test user";

      after = ["keycloak.service"];
      requires = ["keycloak.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
      };

      script = ''
        KCADM=${config.services.keycloak.package}/bin/kcadm.sh

        "$KCADM" config credentials \
          --server http://127.0.0.1:8080 \
          --realm master \
          --user admin \
          --password admin

        if ! "$KCADM" get users \
          -r proconnect-mock \
          -q username=admin@numerique.gouv.fr \
          --fields id \
          --format csv \
          --noquotes | grep -q .; then

          "$KCADM" create users \
            -r proconnect-mock \
            -s username=admin@numerique.gouv.fr \
            -s email=admin@numerique.gouv.fr \
            -s firstName=Admin \
            -s lastName=Tchap \
            -s enabled=true \
            -s emailVerified=true

          "$KCADM" set-password -r tchap --username tchap --new-password tchap
        fi
      '';
    };
  };
}

{
  pkgs,
  ...
}: let
  masSecret = "tchap-dev-mas-secret";

  masConfig = pkgs.writeText "mas-config.yaml" ''
    http:
      listeners:
        - name: web
          resources:
            - name: discovery
            - name: human
            - name: oauth
            - name: compat
            - name: graphql
            - name: assets
          binds:
            - address: "0.0.0.0:8082"
          proxy_protocol: false

        - name: internal
          resources:
            - name: health
          binds:
            - address: "127.0.0.1:8083"
          proxy_protocol: false

      public_base: "http://192.168.77.51:8082/"
      issuer: "http://192.168.77.51:8082/"

    database:
      uri: "postgresql:///matrix-authentication-service?host=/run/postgresql"

    email:
      from: '"Authentication Service" <root@localhost>'
      reply_to: '"Authentication Service" <root@localhost>'
      transport: blackhole

    secrets:
      encryption: "984b18e207c55ad5fbb2a49b217481a722917ee87b2308d4cf314c83fed8e3b5"

    passwords:
      enabled: true
      schemes:
        - version: 1
          algorithm: argon2id
      minimum_complexity: 0

    policy:
      data:
        client_registration:
          allow_insecure_uris: true

    account:
      password_registration_enabled: true

    matrix:
      kind: synapse
      homeserver: "tchap"
      secret: "${masSecret}"
      endpoint: "http://127.0.0.1:8008/"

    rate_limiting:
      login:
        burst: 10
        per_second: 1

      registration:
        burst: 10
        per_second: 1

    tchap:
      identity_server_url: "http://127.0.0.1:8090/"
      email_lookup_fallback_rules:
        - match_with: "@numerique.gouv.fr"
          search: "@beta.gouv.fr"
      tchap_app_link: "http://192.168.77.51/"

    upstream_oauth2:
      providers:
        - id: "01JK5MR1SD21MAQY4PWMFG283W"
          human_name: "ProConnect (mock)"
          issuer: "https://auth.tchap/realms/proconnect-mock"
          token_endpoint_auth_method: client_secret_basic
          client_id: "matrix-authentication-service"
          client_secret: "HrJ1NZ0AbkHuWWjyRHh7X2lzn3S8eagt"
          scope: "openid profile email"

          claims_imports:
            skip_confirmation: true

            localpart:
              action: require
              template: "{{ user.email | email_to_mxid_localpart }}"
              on_conflict: add

            displayname:
              action: require
              template: "{{ user.email | email_to_display_name }}"

            email:
              action: require
              template: "{{ user.email }}"
              set_email_verification: always
  '';
in {
  users.groups.matrix-authentication-service = {};

  users.users.matrix-authentication-service = {
    isSystemUser = true;
    group = "matrix-authentication-service";
  };

  services.postgresql = {
    ensureDatabases = [
      "matrix-authentication-service"
    ];

    ensureUsers = [
      {
        name = "matrix-authentication-service";
        ensureDBOwnership = true;
      }
    ];
  };

  services.matrix-synapse.settings = {
    matrix_authentication_service = {
      enabled = true;
      endpoint = "http://127.0.0.1:8082/";
      secret = masSecret;
    };

    password_config.enabled = false;
    enable_registration = false;
  };

  systemd.services.matrix-authentication-service = {
    description = "Matrix Authentication Service";

    after = [
      "postgresql.target"
      "matrix-synapse.service"
    ];

    requires = [
      "postgresql.target"
    ];

    wantedBy = [
      "multi-user.target"
    ];

    serviceConfig = {
      Type = "simple";

      User = "matrix-authentication-service";
      Group = "matrix-authentication-service";

      ExecStart = "${pkgs.mas-tchap}/bin/mas-cli -c ${masConfig} server";

      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  networking.firewall.allowedTCPPorts = [
    8082
  ];
}

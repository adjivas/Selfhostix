{pkgs, ...}: {
  services.postgresql = {
    enable = true;

    initialScript = pkgs.writeText "matrix-synapse-init.sql" ''
      CREATE ROLE "matrix-synapse" LOGIN;

      CREATE DATABASE "matrix-synapse"
        WITH OWNER "matrix-synapse"
        TEMPLATE template0
        ENCODING = 'UTF8'
        LC_COLLATE = 'C'
        LC_CTYPE = 'C';
    '';
  };

  services.matrix-synapse = {
    enable = true;

    settings = {
      server_name = "tchap";

      registration_shared_secret = "tchap-dev-registration-secret";

      listeners = [
        {
          port = 8008;
          bind_addresses = ["0.0.0.0"];
          type = "http";
          tls = false;

          resources = [
            {
              names = ["client" "federation"];
              compress = false;
            }
          ];
        }
      ];
    };
  };

  systemd.services.matrix-synapse-create-admin = {
    description = "Create Tchap Matrix administrator";

    after = ["matrix-synapse.service"];
    requires = ["matrix-synapse.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
    };

    script = ''
      ${pkgs.matrix-synapse}/bin/register_new_matrix_user \
        --user admin \
        --password tchap \
        --admin \
        --exists-ok \
        --shared-secret tchap-dev-registration-secret \
        http://127.0.0.1:8008
    '';
  };

  networking.firewall.allowedTCPPorts = [8008];
}

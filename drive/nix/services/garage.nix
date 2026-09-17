{
  config,
  lib,
  pkgs,
  ...
}: {
  options.drive.garage = {
    rpcSecret = lib.mkOption {
      type = lib.types.str;
      default = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
      description = "Garage RPC secret.";
    };
    corsOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["https://drive"];
      description = "Origins allowed to access the Drive S3 bucket.";
    };
  };

  config = {
    environment.etc."drive-cors.json".text = builtins.toJSON {
      CORSRules = [
        {
          AllowedOrigins = config.drive.garage.corsOrigins;
          AllowedMethods = ["GET" "PUT" "POST" "DELETE" "HEAD"];
          AllowedHeaders = ["*"];
          ExposeHeaders = ["ETag" "Accept-Ranges" "Content-Length" "Content-Range"];
        }
      ];
    };

    services.garage = {
      enable = true;
      package = pkgs.garage;

      settings = {
        metadata_dir = "/var/lib/garage/meta";
        data_dir = "/var/lib/garage/data";

        replication_factor = 1;

        rpc_bind_addr = "127.0.0.1:3901";
        rpc_public_addr = "127.0.0.1:3901";
        rpc_secret = config.drive.garage.rpcSecret;

        s3_api = {
          api_bind_addr = "127.0.0.1:3900";
          s3_region = "garage";
        };

        admin.api_bind_addr = "127.0.0.1:3903";
      };
    };

    systemd.paths.garage-bootstrap = {
      wantedBy = [
        "multi-user.target"
      ];

      pathConfig = {
        PathExists = "/var/lib/garage/meta/node_key";
        Unit = "garage-bootstrap.service";
      };
    };

    systemd.services.garage-bootstrap = {
      description = "Bootstrap Garage for La Suite Drive";

      after = ["garage.service"];

      requires = ["garage.service"];

      before = ["garage-credentials.service"];

      wants = ["garage-credentials.service"];

      path = [
        config.services.garage.package
        pkgs.awscli2
        pkgs.coreutils
        pkgs.gnugrep
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -eu

        if garage status | grep -q "NO ROLE ASSIGNED"; then
          node_id="$(garage node id -q | cut -d@ -f1)"

          garage layout assign "$node_id" --zone dc1 --capacity 10G

          garage layout apply --version 1
        fi

        if ! garage bucket info drive >/dev/null 2>&1; then
          garage bucket create drive
        fi

        if ! garage key info drive >/dev/null 2>&1; then
          garage key create drive
        fi

        garage bucket allow \
          --read \
          --write \
          --owner drive \
          --key drive


        key_id="$(garage key info drive | sed -n 's/^Key ID: //p')"
        secret_key="$(garage key info --show-secret drive | sed -n 's/^Secret key: //p')"

        AWS_ACCESS_KEY_ID="$key_id" AWS_SECRET_ACCESS_KEY="$secret_key" \
          aws --endpoint-url http://127.0.0.1:3900 --region garage s3api put-bucket-cors \
            --bucket drive --cors-configuration file:///etc/drive-cors.json
      '';
    };

    systemd.services.garage-credentials = {
      description = "Export Garage credentials for La Suite Drive";

      after = ["garage-bootstrap.service"];
      requires = ["garage-bootstrap.service"];
      before = [
        "lasuite-drive.service"
        "lasuite-drive-celery.service"
        "lasuite-drive-beat.service"
      ];
      wants = [
        "lasuite-drive.service"
        "lasuite-drive-celery.service"
        "lasuite-drive-beat.service"
      ];

      path = [
        config.services.garage.package
        pkgs.coreutils
        pkgs.gnused
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "garage-credentials";
        RuntimeDirectoryMode = "0700";
      };

      script = ''
        set -eu

        key_id="$(garage key info drive | sed -n 's/^Key ID: //p')"
        secret_key="$(garage key info --show-secret drive | sed -n 's/^Secret key: //p')"

        cat > /run/garage-credentials/drive.env <<EOF
        AWS_S3_ACCESS_KEY_ID=$key_id
        AWS_S3_SECRET_ACCESS_KEY=$secret_key
        EOF

        chmod 600 /run/garage-credentials/drive.env
      '';
    };
  };
}

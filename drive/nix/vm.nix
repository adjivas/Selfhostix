{
  imports = [
    ./services/garage.nix
    ./services/keycloak.nix
    ./services/nginx.nix
  ];

  networking.hostName = "drive";

  microvm = {
    hypervisor = "cloud-hypervisor";

    vcpu = 2;
    mem = 2048;

    vsock.cid = 3;

    shares = [
      {
        proto = "virtiofs";
        tag = "certs";
        source = "./certs";
        mountPoint = "/mnt/certs";
      }
    ];

    interfaces = [
      {
        type = "tap";
        id = "tap-drive";
        mac = "02:00:00:00:00:50";
        tap.vhost = true;
      }
    ];
  };

  services.lasuite-drive = {
    enable = true;
    domain = "drive";

    postgresql.createLocally = true;
    redis.createLocally = true;

    s3Url = "https://s3.drive/";

    environmentFiles = [
      "/run/garage-credentials/drive.env"
      "/run/keycloak-credentials/drive.env"
    ];

    settings = {
      AWS_S3_ENDPOINT_URL = "https://s3.drive";
      AWS_S3_REGION_NAME = "garage";
      AWS_STORAGE_BUCKET_NAME = "drive";

      OIDC_RP_CLIENT_ID = "drive";
      OIDC_OP_JWKS_ENDPOINT = "https://auth.drive/realms/drive/protocol/openid-connect/certs";
      OIDC_OP_AUTHORIZATION_ENDPOINT = "https://auth.drive/realms/drive/protocol/openid-connect/auth";
      OIDC_OP_TOKEN_ENDPOINT = "https://auth.drive/realms/drive/protocol/openid-connect/token";
      OIDC_OP_USER_ENDPOINT = "https://auth.drive/realms/drive/protocol/openid-connect/userinfo";
      OIDC_OP_LOGOUT_ENDPOINT = "https://auth.drive/realms/drive/protocol/openid-connect/logout";

      REQUESTS_CA_BUNDLE = "/run/nginx-certs/dreamland_cert_root";
    };
  };

  systemd.services = {
    lasuite-drive.wants = ["network-online.target"];
    lasuite-drive-celery.wants = ["network-online.target"];
    lasuite-drive-beat.wants = ["network-online.target"];
  };

  systemd.network = {
    enable = true;

    networks."20-underlay" = {
      matchConfig.MACAddress = "02:00:00:00:00:50";

      address = [
        "192.168.77.50/24"
      ];

      linkConfig.RequiredForOnline = false;
    };
  };

  networking.hosts."127.0.0.1" = ["auth.drive" "s3.drive"];

  services.getty.autologinUser = "root";

  system.stateVersion = "26.05";
}

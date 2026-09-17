{inputs, ...}: {
  imports = [
    inputs.grist-core.nixosModules.default
    ./services/nginx.nix
  ];

  nixpkgs.overlays = [
    inputs.grist-core.overlays.default
  ];

  services.grist = {
    enable = true;
    environment = {
      APP_HOME_URL = "https://grist";
      GRIST_DEFAULT_EMAIL = "admin@localhost";
      # GRIST_HOST = "0.0.0.0";
    };
  };

  networking.hostName = "grist";

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
        id = "tap-grist";
        mac = "02:00:00:00:00:52";
        tap.vhost = true;
      }
    ];
  };

  systemd.network = {
    enable = true;

    networks."20-underlay" = {
      matchConfig.MACAddress = "02:00:00:00:00:52";

      address = [
        "192.168.77.52/24"
      ];

      linkConfig.RequiredForOnline = false;
    };
  };

  services.getty.autologinUser = "root";

  system.stateVersion = "26.05";
}

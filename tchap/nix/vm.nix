{inputs, ...}: {
  imports = [
    ./services/nginx.nix
    ./services/matrix.nix
    ./services/keycloak.nix
    ./services/mas.nix
    ./services/identity.nix
  ];

  nixpkgs.overlays = [
    inputs.self.overlays.default
  ];

  networking.hostName = "tchap";

  microvm = {
    hypervisor = "cloud-hypervisor";

    vcpu = 2;
    mem = 2048;

    vsock.cid = 3;

    # shares = [
    #   {
    #     proto = "virtiofs";
    #     tag = "certs";
    #     source = "./certs";
    #     mountPoint = "/mnt/certs";
    #   }
    # ];

    interfaces = [
      {
        type = "tap";
        id = "tap-tchap";
        mac = "02:00:00:00:00:51";
        tap.vhost = true;
      }
    ];
  };

  systemd.network = {
    enable = true;

    networks."20-underlay" = {
      matchConfig.MACAddress = "02:00:00:00:00:51";

      address = [
        "192.168.77.51/24"
      ];

      linkConfig.RequiredForOnline = false;
    };
  };

  networking.hosts."127.0.0.1" = [ "auth.tchap" ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.getty.autologinUser = "root";

  security.pki.certificateFiles = [
    ../certs/dreamland_cert_root
  ];

  system.stateVersion = "26.05";
}

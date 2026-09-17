{ self, pkgs, ... }: {
  imports = [
  ];

  networking.hostName = "docs";

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
        id = "tap-docs";
        mac = "02:00:00:00:00:53";
        tap.vhost = true;
      }
    ];
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = ["docs"];
    ensureUsers = [
      {
        name = "docs";
        ensureDBOwnership = true;
      }
    ];
  };
  
  services.redis.servers.docs = {
    enable = true;
    port = 6379;
  };

  services.nginx = {
    enable = true;

    virtualHosts."docs.local" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
      };
    };
  };

  environment.systemPackages = [
    pkgs.uv
    pkgs.python314
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/docs 0755 docs docs -"
  ];

  users.users.docs = {
    isSystemUser = true;
    group = "docs";
    home = "/var/lib/docs";
  };

  users.groups.docs = {};

  systemd.services.docs-backend = {
    description = "La Suite Docs backend";

    after = [
      "network.target"
      "postgresql.service"
      "redis-docs.service"
    ];

    requires = [
      "postgresql.service"
      "redis-docs.service"
    ];

    wantedBy = ["multi-user.target"];

    path = [
      pkgs.python314
    ];

    environment = {
      DJANGO_ALLOWED_HOSTS = "*";
      DJANGO_SECRET_KEY = "1c7f2a4e9b6d0834517ecfa2b9046d7c1a8e5f30964b2d7ea1c50f836b924d7f";
      DJANGO_SETTINGS_MODULE = "impress.settings";

      DB_HOST = "127.0.0.1";
      DB_NAME = "docs";
      DB_USER = "docs";
      DB_PORT = "5432";

      PYTHONUNBUFFERED = "1";
      UV_PYTHON_DOWNLOADS = "0";
      UV_PROJECT_ENVIRONMENT = "/var/lib/docs/.venv";

      LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
        pkgs.file
      ];
    };

    serviceConfig = {
      Type = "simple";
      User = "docs";
      Group = "docs";

      WorkingDirectory = "${self}/src/backend";

          # --no-dev \
      ExecStart = ''
        ${pkgs.uv}/bin/uv run \
          --frozen \
          --all-extras \
          uvicorn \
          --host 127.0.0.1 \
          --port 8000 \
          --lifespan off \
          impress.asgi:application
      '';
    };
  };

  systemd.network = {
    enable = true;

    networks."20-underlay" = {
      matchConfig.MACAddress = "02:00:00:00:00:53";
    
      address = [
        "192.168.77.53/24"
      ];
    
      routes = [
        {
          Gateway = "192.168.77.1";
        }
      ];
    
      dns = [
        "1.1.1.1"
      ];
    
      linkConfig.RequiredForOnline = false;
    };
  };

  networking.hosts."127.0.0.1" = [
    "auth.docs"
    "redis"
  ];

  services.getty.autologinUser = "root";

  system.stateVersion = "26.05";
}

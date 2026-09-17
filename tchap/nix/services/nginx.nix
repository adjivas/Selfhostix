{pkgs, ...}: {
  services.nginx = {
    enable = true;

    virtualHosts."auth.tchap" = {
      forceSSL = true;

      sslCertificate = ../../certs/auth.tchap.crt;
      sslCertificateKey = ../../certs/auth.tchap.key;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };

    virtualHosts."tchap" = {
      default = true;
      root = "${pkgs.tchap}";

      # MAS compatibility layer.
      locations."~ ^/_matrix/client/(.*)/(login|logout|refresh)" = {
        proxyPass = "http://127.0.0.1:8082";
        extraConfig = ''
          proxy_http_version 1.1;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        '';
      };

      # Tchap Identity Server.
      locations."~ ^/_matrix/identity" = {
        proxyPass = "http://127.0.0.1:8090";
        extraConfig = ''
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header Host $host;
        '';
      };

      # Matrix / Synapse API.
      locations."~ ^(/_matrix|/_synapse/client|/_synapse/mas)" = {
        proxyPass = "http://127.0.0.1:8008";
        extraConfig = ''
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header Host $host;

          client_max_body_size 50M;
          proxy_http_version 1.1;
        '';
      };

      # Tchap Web.
      locations."/" = {
        tryFiles = "$uri $uri/ /index.html";
      };
    };
  };
}

{
  services.nginx = {
    enable = true;

    virtualHosts."grist" = {
      forceSSL = true;
      sslCertificate = "/run/nginx-certs/grist_cert";
      sslCertificateKey = "/run/nginx-certs/grist_key";

      locations."/" = {
        proxyPass = "http://127.0.0.1:8484";

        proxyWebsockets = true;

        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header X-Forwarded-Port 443;
          proxy_set_header X-Real-IP $remote_addr;
        '';
      };
    };
  };

  systemd.services.nginx-certs = {
    description = "Prepare TLS certificates for Nginx";

    before = [
      "nginx.service"
    ];

    requiredBy = [
      "nginx.service"
    ];

    serviceConfig.Type = "oneshot";

    script = ''
      install -D -m 0644 -o nginx -g nginx /mnt/certs/dreamland_cert_root /run/nginx-certs/dreamland_cert_root
      install -D -m 0644 -o nginx -g nginx /mnt/certs/grist_cert /run/nginx-certs/grist_cert
      install -D -m 0400 -o nginx -g nginx /mnt/certs/grist_key /run/nginx-certs/grist_key
    '';
  };

  networking.firewall.allowedTCPPorts = [
    443
  ];
}

{
  services.nginx = {
    virtualHosts."drive" = {
      forceSSL = true;
      sslCertificate = "/run/nginx-certs/drive_cert";
      sslCertificateKey = "/run/nginx-certs/drive_key";
    };

    virtualHosts."auth.drive" = {
      forceSSL = true;
      sslCertificate = "/run/nginx-certs/drive_cert";
      sslCertificateKey = "/run/nginx-certs/drive_key";

      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";

        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header X-Forwarded-Port 443;
          proxy_set_header X-Real-IP $remote_addr;
        '';
      };
    };

    virtualHosts."s3.drive" = {
      forceSSL = true;
      sslCertificate = "/run/nginx-certs/drive_cert";
      sslCertificateKey = "/run/nginx-certs/drive_key";

      locations."/" = {
        proxyPass = "http://127.0.0.1:3900";

        extraConfig = ''
          proxy_set_header Host $host;
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
      install -D -m 0644 -o nginx -g nginx /mnt/certs/drive_cert /run/nginx-certs/drive_cert
      install -D -m 0400 -o nginx -g nginx /mnt/certs/drive_key /run/nginx-certs/drive_key
    '';
  };

  networking.firewall.allowedTCPPorts = [
    443
  ];
}

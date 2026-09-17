{pkgs, ...}: {
  systemd.services.tchap-identity = {
    description = "Tchap Identity Server mock";

    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";

      ExecStart = ''
        ${pkgs.wiremock}/bin/wiremock \
          --root-dir ${../wiremock} \
          --port 8090 \
          --bind-address 127.0.0.1 \
          --verbose \
          --global-response-templating
      '';

      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}

{
  description = "La Suite Tchap";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    grist-core = {
      url = "path:/home/adjivas/PoCs/LaSuiteNumerique/grist-core";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    flake-parts,
    microvm,
    nixpkgs,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      inherit systems;

      flake.nixosConfigurations = nixpkgs.lib.genAttrs systems (
        system:
          nixpkgs.lib.nixosSystem {
            inherit system;

            specialArgs = {
              inherit inputs;
            };

            modules = [
              microvm.nixosModules.microvm
              ./nix/vm.nix
            ];
          }
      );

      perSystem = {
        system,
        pkgs,
        ...
      }: let
        vm = inputs.self.nixosConfigurations.${system}.config.microvm.declaredRunner;

        run-vm = pkgs.writeShellApplication {
          name = "run-grist";

          text = ''
            runner=${vm}
            config=$(mktemp)

            sed '/^user=root$/d' \
              "$(sed -n 's/.*--configuration \([^ ]*\).*/\1/p' "$runner/bin/virtiofsd-run")" \
              > "$config"

            $(sed -n 's/^exec \([^ ]*supervisord\).*/\1/p' "$runner/bin/virtiofsd-run") \
              --configuration "$config" &
            pid=$!

            trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; rm -f "$config"' EXIT

            sleep 1
            "$runner/bin/microvm-run"
          '';
        };
      in {
        packages = {
          inherit vm;

          default = vm;
        };

        apps = {
          vm = {
            type = "app";
            program = pkgs.lib.getExe run-vm;
          };
        };

        formatter = pkgs.alejandra;
      };
    };
}

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

    mas-tchap = {
      url = "github:tchapgouv/matrix-authentication-service/642c95c780f994afc7478f8eefb4c7ec9b9b15f7";
      flake = false;
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

      flake.overlays.default = final: prev: {
        tchap = final.callPackage ./nix/package.nix {};

        mas-tchap = final.callPackage ./nix/package-mas.nix {
          inherit inputs;
        };
      };

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
          name = "run-tchap";

          text = ''
            exec ${vm}/bin/microvm-run
          '';
          # text = ''
          #   runner=${vm}
          #   config=$(mktemp)
          #
          #   sed '/^user=root$/d' \
          #     "$(sed -n 's/.*--configuration \([^ ]*\).*/\1/p' "$runner/bin/virtiofsd-run")" \
          #     > "$config"
          #
          #   $(sed -n 's/^exec \([^ ]*supervisord\).*/\1/p' "$runner/bin/virtiofsd-run") \
          #     --configuration "$config" &
          #   pid=$!
          #
          #   trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; rm -f "$config"' EXIT
          #
          #   sleep 1
          #   "$runner/bin/microvm-run"
          # '';
        };

        tchap = pkgs.callPackage ./nix/package.nix {};
        mas-tchap = pkgs.callPackage ./nix/package-mas.nix {
          inherit inputs;
        };
      in {
        packages = {
          inherit vm tchap mas-tchap;

          default = vm;
        };

        apps = {
          vm = {
            type = "app";
            program = pkgs.lib.getExe run-vm;
          };
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.nodejs
            pkgs.corepack
          ];
        };

        formatter = pkgs.alejandra;
      };
    };
}

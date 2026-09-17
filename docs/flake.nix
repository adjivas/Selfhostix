{
  description = "La Suite Docs";

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
              self = inputs.self;
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
        lib,
        ...
      }: let
        vm = inputs.self.nixosConfigurations.${system}.config.microvm.declaredRunner;

        run-vm = pkgs.writeShellApplication {
          name = "run-docs";

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

        docs-frontend = pkgs.stdenv.mkDerivation {
          pname = "docs-frontend";
          version = "5.7.0";

          src = "${inputs.self}/src/frontend";

          yarnOfflineCache = pkgs.fetchYarnDeps {
            yarnLock = "${inputs.self}/src/frontend/yarn.lock";
            hash = "sha256-OM97Y4gCCLcAUngaSW8QSmuu7+Lm8wF+KQP60sjIfHI=";
          };

          nativeBuildInputs = [
            pkgs.nodejs_24
            pkgs.yarn
            pkgs.yarnConfigHook
          ];

          buildPhase = ''
            runHook preBuild

            export HOME=$TMPDIR
            export NEXT_TELEMETRY_DISABLED=1
            export NEXT_PUBLIC_API_ORIGIN=http://docs.local

            yarn install \
              --frozen-lockfile \
              --ignore-engines \
              --offline

            yarn app:build

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out
            cp -r apps/impress/out/. $out/

            runHook postInstall
          '';
        };
      in {
        packages = {
          inherit vm docs-frontend;

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

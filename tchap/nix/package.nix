{
  stdenv,
  lib,
  nodejs,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "tchap-web";
  version = "4.21.5";

  src = ../.;

  env = {
    NX_NATIVE_COMMAND_RUNNER = "false";
    NX_DAEMON = "false";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;

    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = "sha256-42kmX5DOUtsdcnupYWEHYsrjKnJH2gXzJPh/IknDK4Y=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm_10
    pnpmConfigHook
  ];

  buildPhase = ''
    runHook preBuild

    node scripts/pnpm-link.ts
    ./scripts/tchap/apply_patches.sh

    pnpm --dir packages/shared-components build
    pnpm --dir apps/web build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r apps/web/webapp/. $out/
    cp ${./config.json} $out/config.json
    echo "${finalAttrs.version}" > $out/version

    runHook postInstall
  '';

  meta = {
    description = "Tchap web client";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
})

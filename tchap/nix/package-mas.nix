{
  inputs,
  lib,
  rustPlatform,
  fetchPnpmDeps,
  pnpm,
  pnpmConfigHook,
  nodejs,
  python3,
  pkg-config,
  sqlite,
  zstd,
  stdenv,
  open-policy-agent,
  cctools,
  buildPackages,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "matrix-authentication-service-tchap";
  version = "0.16.0-alpha.4";

  src = inputs.mas-tchap;

  cargoHash = "sha256-t9ilOIP5lVuNwQC0xPI/8AT2Xn3v19ZQSiknPeq5Ik4=";

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 4;
    hash = "sha256-FlvdNOvZDis5Pl+64kZBLJ+DDrUf/swr1HVJR/CrZCs=";
  };

  pnpmRoot = "frontend";

  nativeBuildInputs = [
    pkg-config
    open-policy-agent
    pnpmConfigHook
    pnpm
    nodejs
    (python3.withPackages (ps: [ps.setuptools]))
  ]
  ++ lib.optional stdenv.hostPlatform.isDarwin cctools;

  buildInputs = [
    sqlite
    zstd
  ];

  depsBuildBuild = [
    buildPackages.stdenv.cc
  ];

  env = {
    ZSTD_SYS_USE_PKG_CONFIG = true;
    VERGEN_GIT_DESCRIBE = finalAttrs.version;
  };

  buildNoDefaultFeatures = true;
  buildFeatures = ["dist"];

  postPatch = ''
    substituteInPlace crates/config/src/sections/http.rs \
      --replace-fail ./share/assets/ "$out/share/$pname/assets/"

    substituteInPlace crates/config/src/sections/templates.rs \
      --replace-fail ./share/templates/ "$out/share/$pname/templates/" \
      --replace-fail ./share/translations/ "$out/share/$pname/translations/" \
      --replace-fail ./share/manifest.json "$out/share/$pname/assets/manifest.json"

    substituteInPlace crates/config/src/sections/policy.rs \
      --replace-fail ./share/policy.wasm "$out/share/$pname/policy.wasm"
  '';

  preBuild = let
    buildTarget = stdenv.buildPlatform.rust.rustcTarget;
    buildTargetUnderscore = lib.replaceString "-" "_" buildTarget;
  in ''
    make -C policies
    (cd "$pnpmRoot" && npm run build-tchap)

    export CC_${buildTargetUnderscore}=$CC_FOR_BUILD
    export CXX_${buildTargetUnderscore}=$CXX_FOR_BUILD
  '';

  postInstall = ''
    install -Dm444 -t "$out/share/$pname" \
      "policies/policy.wasm"

    install -Dm444 -t "$out/share/$pname" \
      "$pnpmRoot/dist/manifest.json"

    install -Dm444 -t "$out/share/$pname/assets" \
      "$pnpmRoot/dist/"*

    cp -r templates "$out/share/$pname/templates"
    cp -r tchap/resources/templates/. "$out/share/$pname/templates/"

    cp -r tchap/resources/translations \
      "$out/share/$pname/translations"
  '';
})

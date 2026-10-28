{
  lib,
  stdenvNoCC,
  rustPlatform,
  fetchFromGitHub,
  bun,
  jq,
  writableTmpDirAsHomeHook,
}:
let
  version = "0.4.19";

  src = fetchFromGitHub {
    owner = "devswha";
    repo = "ovis";
    tag = "v${version}";
    hash = "sha256-0MKjG/i4GSqLQIISqCJi5PbyAsax2EGADsV9Spj6IzU=";
  };

  ptySidecar = rustPlatform.buildRustPackage {
    pname = "ovis-pty-sidecar";
    inherit version src;
    sourceRoot = "${src.name}/crates/pty-sidecar";
    cargoHash = "sha256-vin5SGninwkDlpWIK4Cc5oO4cZ7DjTXDovUpu0fWwlE=";
  };

  # Bun applies patchedDependencies here. Install scripts stay off: the
  # native packages Ovis needs ship prebuilt per-platform binaries.
  # `build` has the dev tools for vite. `runtime` is what the server loads.
  nodeModules = stdenvNoCC.mkDerivation {
    pname = "ovis-node-modules";
    inherit version src;
    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];
    dontConfigure = true;
    dontFixup = true;
    buildPhase = ''
      runHook preBuild
      flags="--frozen-lockfile --ignore-scripts --no-progress --os=linux --cpu=x64"
      mkdir build runtime
      for dir in build runtime; do
        cp -r package.json bun.lock patches "$dir/"
      done
      (cd build && bun install $flags)
      (cd runtime && bun install $flags --production)
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/build" "$out/runtime"
      cp -r build/node_modules "$out/build/"
      cp -r runtime/node_modules "$out/runtime/"
      runHook postInstall
    '';
    outputHash = "sha256-jTpGwoGzFdursNolKrvpm0NFsYspYRpCYQGS8W2Rm/M=";
    outputHashMode = "recursive";
  };
in
stdenvNoCC.mkDerivation {
  pname = "ovis";
  inherit version src;

  nativeBuildInputs = [
    bun
    jq
    writableTmpDirAsHomeHook
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    cp -r ${nodeModules}/build/node_modules .
    chmod -R u+w node_modules
    # `bun run build` execs vite's `/usr/bin/env node` shebang, which the sandbox lacks.
    bun --bun node_modules/vite/bin/vite.js build
    runHook postBuild
  '';

  # The plugin runs from the read-only store, so the build ships the PTY host
  # and its record. The supervisor then does not try to download one into bin/.
  # The record's crate field is a git tree id that only the downloader reads.
  installPhase = ''
    runHook preInstall
    rm -rf node_modules app docs ovis-site
    cp -r ${nodeModules}/runtime/node_modules .
    install -Dm755 ${ptySidecar}/bin/ovis-pty-sidecar bin/ovis-pty-sidecar
    jq -n --arg sha256 "$(sha256sum bin/ovis-pty-sidecar | cut -d' ' -f1)" --arg version ${version} \
      '{crate: "nix", sha256: $sha256, version: $version}' > bin/ovis-pty-sidecar.json
    substituteInPlace herdr-plugin.toml \
      --replace-fail '"sh", "scripts/with-bun.sh", ' '"${lib.getExe bun}", '
    mkdir -p "$out"
    cp -r . "$out"
    runHook postInstall
  '';

  meta = {
    description = "Browser and phone client for Herdr";
    homepage = "https://github.com/devswha/ovis";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}

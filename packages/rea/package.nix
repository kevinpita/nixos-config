{
  lib,
  stdenv,
  autoPatchelfHook,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_22,
  makeWrapper,
  procps,
  ghidra,
  openjdk21,
}:

buildNpmPackage (finalAttrs: {
  pname = "rea";
  version = "6.8.0";

  # The npm tarball has no lockfile, so build the tagged source.
  src = fetchFromGitHub {
    owner = "morluto";
    repo = "rea";
    tag = "rea-agents-${finalAttrs.version}";
    hash = "sha256-2ADn3U3lvUoB4tCEpzO0rMfYE4sis+5uBiEazcp0gpI=";
  };

  npmDepsHash = "sha256-3WPXD+qm5WVfrTEvepKwX5RZBfbLBcPB0uDmKIx4MR8=";

  # nixpkgs Node 24 is older than REA's ^24.22.1 minimum, and REA's
  # TypeScript loader fails on Node 26.
  nodejs = nodejs_22;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  # npm installs prebuilt glibc and musl binaries. Only the glibc ones can load here.
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

  # prepare installs git hooks and patches release tooling for development.
  npmFlags = [ "--ignore-scripts" ];

  # npm pack in installPhase runs prepare and prepack even with
  # --ignore-scripts. prepack only repeats the build below.
  preInstall = ''
    npm pkg delete scripts.prepare scripts.prepack
  '';

  # build:cached adds turbo caching and dependency checks around these steps.
  buildPhase = ''
    runHook preBuild
    # The build runs the prebuilt tsrs TypeScript compiler before fixupPhase patches it.
    autoPatchelf node_modules/@tsrs
    npm run compile
    node scripts/generate-skill-metadata.mjs
    runHook postBuild
  '';

  # REA needs a procps ps for process ownership checks. Ghidra is the
  # native provider; callers can still override GHIDRA_INSTALL_DIR.
  postInstall = ''
    for bin in rea rea-agents; do
      wrapProgram $out/bin/$bin \
        --prefix PATH : ${lib.makeBinPath [ procps ]} \
        --set-default GHIDRA_INSTALL_DIR ${ghidra}/lib/ghidra \
        --set-default JAVA_HOME ${openjdk21}
    done
  '';

  passthru.skill = "${finalAttrs.finalPackage}/lib/node_modules/rea-agents/skills/reverse-engineer-anything";

  meta = {
    description = "Reverse engineer binaries, applications, and runtime behavior with agents";
    homepage = "https://github.com/morluto/rea";
    license = lib.licenses.mit;
    mainProgram = "rea";
    platforms = lib.platforms.linux;
  };
})

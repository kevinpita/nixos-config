{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  installShellFiles,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "exrpd";
  version = "11.2.0";

  # Prebuilt upstream release; bump version and hash manually.
  src = fetchurl {
    url = "https://github.com/xrplevm/node/releases/download/v${finalAttrs.version}/node_${finalAttrs.version}_Linux_amd64.tar.gz";
    hash = "sha256-MApleb0PvaVtmDe7OXbggGjLbSkonyc7GaBGUoacOsU=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    installShellFiles
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/exrpd $out/bin/exrpd
    runHook postInstall
  '';

  # Patch before the fixup hook so the binary can generate its completions.
  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    autoPatchelf $out/bin
    export HOME=$TMPDIR
    installShellCompletion --cmd exrpd \
      --bash <($out/bin/exrpd completion) \
      --zsh <($out/bin/exrpd completion --zsh)
  '';

  meta = {
    description = "XRPL EVM sidechain node daemon";
    homepage = "https://github.com/xrplevm/node";
    changelog = "https://github.com/xrplevm/node/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "exrpd";
    platforms = [ "x86_64-linux" ];
  };
})

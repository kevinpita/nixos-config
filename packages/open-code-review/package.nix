{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  git,
  installShellFiles,
}:

buildGoModule (finalAttrs: {
  pname = "open-code-review";
  version = "1.13.3";

  src = fetchFromGitHub {
    owner = "alibaba";
    repo = "open-code-review";
    tag = "v${finalAttrs.version}";
    hash = "sha256-dDKNxjI0pWoJGabUvsGTERYKvKtvEm3UGD/FLPKpfnw=";
  };

  vendorHash = "sha256-LpqnNp6gxHatHH68pM59ESQICDDSVrkZm7AJLVvYTao=";
  subPackages = [ "cmd/opencodereview" ];

  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
    "-X main.Version=v${finalAttrs.version}"
    "-X main.GitCommit=${finalAttrs.src.tag}"
  ];

  nativeBuildInputs = [ installShellFiles ];

  # Upstream tests create Git repositories.
  nativeCheckInputs = [ git ];

  # Upstream docs and the npm package call the binary `ocr`.
  postInstall = ''
    ln -s opencodereview "$out/bin/ocr"
  ''
  + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    export HOME=$TMPDIR
    installShellCompletion --cmd ocr \
      --bash <($out/bin/ocr completion bash) \
      --zsh <($out/bin/ocr completion zsh) \
      --fish <($out/bin/ocr completion fish)
  '';

  meta = {
    description = "AI code review CLI with deterministic file selection and per-language rules";
    homepage = "https://github.com/alibaba/open-code-review";
    changelog = "https://github.com/alibaba/open-code-review/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "ocr";
    platforms = lib.platforms.unix;
  };
})

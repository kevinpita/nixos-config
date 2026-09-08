{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule {
  pname = "herdr-auto-title";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "kryptamine";
    repo = "herdr-auto-title";
    rev = "899ee4e4c827129c9920c105f250628ff967ca98";
    hash = "sha256-bF3qtMeyjixfpXEHN+/KrSaiOOKj+ePFxkSpm5d8RNI=";
  };

  vendorHash = "sha256-QxFp1b7pf7bn3Hh0hyaj8ke5Z61N+WwjhHt3pFiapTs=";
  subPackages = [ "cmd/herdr-auto-title" ];

  checkPhase = ''
    runHook preCheck
    go test ./...
    runHook postCheck
  '';

  postInstall = ''
    cp herdr-plugin.toml "$out/herdr-plugin.toml"
    ln -s "$out/bin/herdr-auto-title" "$out/herdr-auto-title"
  '';

  meta = {
    description = "Automatic contextual tab titles for Herdr";
    homepage = "https://github.com/kryptamine/herdr-auto-title";
    license = lib.licenses.mit;
    mainProgram = "herdr-auto-title";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}

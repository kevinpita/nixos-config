{
  writeShellApplication,
  curl,
  gnugrep,
  gnused,
  jq,
}:

# Run from the repository root, before `nix flake update`. Moves the oh-my-pi
# input in flake.nix and the prebuilt native addon in omp/natives.json to the
# newest omp release, so that both always have the same version.
writeShellApplication {
  name = "omp-pin-release";
  runtimeInputs = [
    curl
    gnugrep
    gnused
    jq
  ];
  text = ''
    meta=$(curl --fail --silent --show-error --location \
      https://registry.npmjs.org/@oh-my-pi/pi-natives-linux-x64/latest)
    version=$(jq --raw-output .version <<<"$meta")
    hash=$(jq --raw-output .dist.integrity <<<"$meta")
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || $hash != sha512-* ]]; then
      echo "Unexpected omp release metadata: version '$version', hash '$hash'" >&2
      exit 1
    fi

    sed --in-place --regexp-extended \
      "s#(github:can1357/oh-my-pi/v)[0-9.]+#\1$version#" flake.nix
    if ! grep --quiet --fixed-strings "github:can1357/oh-my-pi/v$version\"" flake.nix; then
      echo "flake.nix has no oh-my-pi release tag to update" >&2
      exit 1
    fi
    jq --null-input --arg version "$version" --arg hash "$hash" \
      '{ version: $version, hash: $hash }' > omp/natives.json
  '';
}

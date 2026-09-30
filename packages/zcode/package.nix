{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs_24,
  autoPatchelfHook,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "zcode";
  version = "0.16.9";

  src = fetchFromGitHub {
    owner = "zai-org";
    repo = "ZCode";
    rev = "29628c9acdb81b703bbd4080c207a0e7ce5e276e";
    hash = "sha256-4LZIl6ofaxcmb28fu21Kc5oJAe+/AKRDAM/2xRKYxI8=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-0N0NDwkblR9bSskfZLA0SOxhs7W2hELDIAHohOynTOg=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    nodejs_24
    pnpm_10
    pnpmConfigHook
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  buildPhase = ''
    runHook preBuild
    patchShebangs apps/zcode-cli packages
    pnpm --filter @zcode/cli... build
    pnpm --filter @zcode/shared exec tsc
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    node --input-type=module <<'EOF'
    import { copyFile, cp, mkdir } from "node:fs/promises";
    import { createRequire } from "node:module";
    import { dirname, resolve } from "node:path";
    import { collectSeaTuiAssets, seaTuiAssetPrefix } from "./apps/zcode-cli/packages/cli/scripts/sea-tui-assets.mjs";

    const runtime = resolve(process.env.out, "lib/zcode");
    const cliDirectory = resolve("apps/zcode-cli/packages/cli");
    const { assets, manifest } = await collectSeaTuiAssets({
      root: resolve("apps/zcode-cli"),
      stagingDirectory: resolve("tui-assets"),
      target: "linux-x64",
    });
    await cp(resolve(cliDirectory, "dist"), runtime, { recursive: true });
    for (const file of manifest.files) {
      const destination = resolve(runtime, file.path);
      await mkdir(dirname(destination), { recursive: true });
      await copyFile(assets[seaTuiAssetPrefix + file.path], destination);
    }
    const require = createRequire(resolve(cliDirectory, "package.json"));
    await cp(dirname(require.resolve("playwright-core/package.json")), resolve(runtime, "node_modules/playwright-core"), { recursive: true });
    await cp("apps/zcode-cli/packages/bundled-skills", resolve(runtime, "packages/bundled-skills"), { recursive: true });
    EOF

    makeWrapper ${nodejs_24}/bin/node "$out/bin/zcode" \
      --add-flags "$out/lib/zcode/zcode.cjs"

    runHook postInstall
  '';

  meta = {
    description = "Z.ai terminal coding agent";
    homepage = "https://github.com/zai-org/ZCode";
    license = lib.licenses.asl20;
    mainProgram = "zcode";
    platforms = [ "x86_64-linux" ];
  };
})

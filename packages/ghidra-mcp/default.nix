{
  fetchurl,
  lib,
  makeWrapper,
  python3Packages,
  stdenvNoCC,
  symlinkJoin,
  unzip,
}:

let
  pname = "ghidra-mcp";
  version = "5.14.2";

  extensionZip = fetchurl {
    url = "https://github.com/bethington/ghidra-mcp/releases/download/v${version}/GhidraMCP-${version}.zip";
    hash = "sha256-LDPNUlT4+kqOfHQj29ZDOEJoD5p2vBWyl7DfcV8iml0=";
  };

  bridgeScript = fetchurl {
    url = "https://github.com/bethington/ghidra-mcp/releases/download/v${version}/bridge_mcp_ghidra.py";
    hash = "sha256-ktmnkNFIxJ0KiJ21DnNhoQ1ASN+Y83ITYsvWa5dCdVw=";
  };

  pythonEnv = python3Packages.python.withPackages (ps: [ ps.mcp ]);

  extension = stdenvNoCC.mkDerivation {
    pname = "ghidra-mcp-extension";
    inherit version;

    src = extensionZip;
    nativeBuildInputs = [ unzip ];
    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/ghidra/Ghidra/Extensions
      unzip -q $src -d $out/lib/ghidra/Ghidra/Extensions
      touch $out/lib/ghidra/Ghidra/Extensions/GhidraMCP/.dbDirLock

      runHook postInstall
    '';

    meta = {
      description = "GhidraMCP plugin for Ghidra";
      homepage = "https://github.com/bethington/ghidra-mcp";
      license = lib.licenses.asl20;
      platforms = lib.platforms.linux;
      sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    };
  };

  bridge = stdenvNoCC.mkDerivation {
    pname = "ghidra-mcp-bridge";
    inherit version;

    src = bridgeScript;
    nativeBuildInputs = [ makeWrapper ];
    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      install -Dm0644 $src $out/share/ghidra-mcp/bridge_mcp_ghidra.py
      makeWrapper ${pythonEnv}/bin/python $out/bin/bridge-mcp-ghidra \
        --add-flags $out/share/ghidra-mcp/bridge_mcp_ghidra.py
      ln -s bridge-mcp-ghidra $out/bin/ghidra-mcp-bridge

      runHook postInstall
    '';

    meta = {
      description = "MCP bridge for the GhidraMCP Ghidra plugin";
      homepage = "https://github.com/bethington/ghidra-mcp";
      license = lib.licenses.asl20;
      mainProgram = "bridge-mcp-ghidra";
      platforms = lib.platforms.linux;
    };
  };
in
symlinkJoin {
  name = "${pname}-${version}";
  paths = [
    bridge
    extension
  ];

  passthru = {
    inherit bridge extension;
  };

  meta = {
    description = "GhidraMCP bridge and Ghidra extension";
    homepage = "https://github.com/bethington/ghidra-mcp";
    license = lib.licenses.asl20;
    mainProgram = "bridge-mcp-ghidra";
    platforms = lib.platforms.linux;
  };
}

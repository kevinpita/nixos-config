{
  python3Packages,
  ghidra,
  ghidra-extensions,
  openjdk21,
  makeWrapper,
}:

let
  # The Python CLI drives the ReVa Java extension, so both come from the same release.
  ghidraWithReva = ghidra.withExtensions (exts: [ exts.reva ]);
in
python3Packages.buildPythonApplication {
  pname = "mcp-reva";
  inherit (ghidra-extensions.reva) version src meta;
  pyproject = true;

  # Upstream stdio mode always uses a throwaway temp project.
  patches = [ ./persistent-project.patch ];

  nativeBuildInputs = [ makeWrapper ];

  env.SETUPTOOLS_SCM_PRETEND_VERSION = ghidra-extensions.reva.version;

  build-system = with python3Packages; [
    setuptools
    setuptools-scm
  ];

  dependencies = with python3Packages; [
    httpx
    httpx-sse
    mcp
    pyghidra
  ];

  makeWrapperArgs = [
    "--set GHIDRA_INSTALL_DIR ${ghidra}/lib/ghidra"
    # nixpkgs Ghidra finds extensions through NIX_GHIDRAHOME, not the install dir.
    "--set NIX_GHIDRAHOME ${ghidraWithReva}/lib/ghidra/Ghidra"
    "--set JAVA_HOME ${openjdk21}"
  ];

  # ghidra-python runs PyGhidra scripts against the same Ghidra, for project setup outside MCP.
  postInstall = ''
    makeWrapper ${
      python3Packages.python.withPackages (ps: [ ps.pyghidra ])
    }/bin/python3 $out/bin/ghidra-python \
      --set GHIDRA_INSTALL_DIR ${ghidra}/lib/ghidra \
      --set NIX_GHIDRAHOME ${ghidraWithReva}/lib/ghidra/Ghidra \
      --set JAVA_HOME ${openjdk21}
  '';

  pythonImportsCheck = [ "reva_cli" ];

  passthru.ghidra = ghidraWithReva;
}

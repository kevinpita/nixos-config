{
  config,
  lib,
  pkgs,
  ...
}:
let
  ghidraWithMcp = pkgs.ghidra.withExtensions (_extensions: [ pkgs.ghidra-mcp-extension ]);
in
lib.mkIf config.features.reverse-engineering.enable {
  environment = {
    systemPackages = [
      ghidraWithMcp
      pkgs.ghidra-mcp-bridge
    ];

    sessionVariables = {
      GHIDRA_MCP_REQUIRE_PROGRAM_SELECTORS = "1";
    };
  };
}

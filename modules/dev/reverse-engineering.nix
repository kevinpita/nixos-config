{
  flake.modules.nixos.reverse-engineering =
    { pkgs, ... }:
    let
      ghidraWithMcp = pkgs.ghidra.withExtensions (_extensions: [ pkgs.ghidra-mcp-extension ]);
    in
    {
      environment = {
        systemPackages = [
          ghidraWithMcp
          pkgs.ghidra-mcp-bridge
        ];

        sessionVariables = {
          GHIDRA_MCP_REQUIRE_PROGRAM_SELECTORS = "1";
        };
      };
    };
}

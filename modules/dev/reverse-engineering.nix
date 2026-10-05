{
  flake.modules.nixos.reverse-engineering =
    { pkgs, ... }:
    {
      # mcp-reva runs Ghidra headless as an MCP server; its Ghidra bundles the matching ReVa extension.
      environment.systemPackages = [
        pkgs.mcp-reva
        pkgs.mcp-reva.ghidra
      ];
    };
}

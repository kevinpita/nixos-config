{
  flake.modules.nixos.reverse-engineering =
    { pkgs, ... }:
    {
      # mcp-reva runs Ghidra headless as an MCP server; its Ghidra bundles the matching ReVa extension.
      environment.systemPackages = [
        pkgs.mcp-reva
        pkgs.mcp-reva.ghidra
      ];

      # REA (morluto/rea) uses Ghidra headless from GHIDRA_INSTALL_DIR and needs a full JDK 21+.
      environment.variables.GHIDRA_INSTALL_DIR = "${pkgs.ghidra}/lib/ghidra";
      programs.java = {
        enable = true;
        package = pkgs.openjdk21;
      };
    };
}

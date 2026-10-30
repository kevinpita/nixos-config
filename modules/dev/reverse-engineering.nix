{
  flake.modules.nixos.reverse-engineering =
    { lib, pkgs, ... }:
    let
      # Gives `omp --rea` REA's MCP server and its reverse-engineer-anything skill.
      reaOmpPlugin = pkgs.runCommand "rea-omp-plugin" { } ''
        mkdir -p "$out/.claude-plugin" "$out/skills"
        echo '{"name": "rea", "version": "${pkgs.rea.version}"}' > "$out/.claude-plugin/plugin.json"
        ln -s ${pkgs.rea.skill} "$out/skills/reverse-engineer-anything"
        cat > "$out/.mcp.json" <<'EOF'
        {"mcpServers": {"rea": {"command": "${lib.getExe pkgs.rea}", "args": ["mcp"]}}}
        EOF
      '';
    in
    {
      environment.systemPackages = [
        # mcp-reva runs Ghidra headless as an MCP server; its Ghidra bundles the matching ReVa extension.
        pkgs.mcp-reva
        pkgs.mcp-reva.ghidra
        # REA brings its own Ghidra, JDK, and Node. ilspycmd decompiles .NET assemblies to C#.
        pkgs.rea
        pkgs.ilspycmd
      ];

      # Requires the ai aspect, which declares omp.optInPluginDirs.
      omp.optInPluginDirs.rea = reaOmpPlugin;
    };
}

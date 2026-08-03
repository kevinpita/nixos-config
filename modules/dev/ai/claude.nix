{
  flake.modules.nixos.ai =
    { pkgs, username, ... }:
    let
      herdrClaudeIntegration = pkgs.runCommand "herdr-claude-integration" { } ''
        export HOME="$out"
        mkdir -p "$HOME/.claude"
        printf '{}\n' > "$HOME/.claude/settings.json"
        ${pkgs.herdr}/bin/herdr integration install claude
      '';
    in
    {
      environment.systemPackages = [ pkgs.claude-code ];

      home-manager.users.${username}.home.file = {
        ".claude/settings.json" = {
          source = ./claude-settings.json;
          force = true;
        };
        ".claude/hooks/herdr-agent-state.sh".source =
          "${herdrClaudeIntegration}/.claude/hooks/herdr-agent-state.sh";
        ".claude/skills/herdr".source = "${pkgs.herdr}/share/herdr/skills/herdr";
      };
    };
}

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

      home-manager.users.${username} =
        { config, ... }:
        {
          home.file = {
            # Out-of-store symlink so Claude Code can edit its own settings at
            # runtime; changes land in the repo working tree as a git diff.
            ".claude/settings.json" = {
              source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/modules/dev/ai/claude-settings.json";
              force = true;
            };
            ".claude/hooks/herdr-agent-state.sh".source =
              "${herdrClaudeIntegration}/.claude/hooks/herdr-agent-state.sh";
          };
        };
    };
}

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
        { config, lib, ... }:
        {
          home.file.".claude/hooks/herdr-agent-state.sh".source =
            "${herdrClaudeIntegration}/.claude/hooks/herdr-agent-state.sh";

          # Direct symlink to the repo file so Claude Code can edit its own
          # settings at runtime, changes land in the working tree as a git diff.
          # mkOutOfStoreSymlink does not work here: it links through the Nix
          # store, and Claude Code writes its temp file next to the first hop,
          # which fails with EROFS.
          home.activation.linkClaudeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            run ln -sfn $VERBOSE_ARG \
              "${config.home.homeDirectory}/nixos-config/modules/dev/ai/claude-settings.json" \
              "${config.home.homeDirectory}/.claude/settings.json"
          '';
        };
    };
}

{
  flake.modules.nixos.ai =
    {
      config,
      pkgs,
      username,
      ...
    }:
    let
      repo = config.programs.nh.flake;
    in
    {
      environment.systemPackages = [ pkgs.claude-code ];

      home-manager.users.${username} =
        { config, lib, ... }:
        {
          home.file = {
            # Claude Code reads one instruction file, so it gets both as one.
            ".claude/CLAUDE.md".text =
              builtins.readFile ../../../agents/AGENTS.md + "\n" + builtins.readFile ../../../agents/RULES.md;
            # Reports Claude Code agent state to herdr. Same file that
            # `herdr integration install claude` writes, pinned to the package.
            # claude-settings.json runs it from the SessionStart hook.
            ".claude/hooks/herdr-agent-state.sh" = lib.mkIf config.programs.herdr.enable {
              source = "${config.programs.herdr.package}/share/herdr/integrations/claude/herdr-agent-state.sh";
            };
          };

          # A direct symlink to the repo file, so Claude Code can edit its own
          # settings and the edits land in the working tree as a git diff.
          # mkOutOfStoreSymlink links through the read-only Nix store, where
          # Claude Code cannot write its temp file.
          home.activation.linkClaudeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            run mkdir -p $VERBOSE_ARG "${config.home.homeDirectory}/.claude"
            run ln -sfn $VERBOSE_ARG \
              "${repo}/modules/dev/ai/claude-settings.json" \
              "${config.home.homeDirectory}/.claude/settings.json"
          '';
        };
    };
}

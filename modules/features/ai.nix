{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.ai.enable {
  environment.systemPackages = with pkgs; [
    codex
    claude-code
    gemini-cli
    herdr
    pi-coding-agent

    rtk

    bubblewrap # codex dependency
    fd # pi dependency
  ];

  home-manager.users.${username} = {
    xdg.configFile."herdr/config.toml" = {
      force = true;
      text = ''
        onboarding = false

        [theme]
        name = "dracula"

        [ui]
        show_agent_labels_on_pane_borders = true
        agent_panel_scope = "all"

        [[keys.command]]
        key = "g"
        type = "pane"
        command = "lazygit"

        [[keys.command]]
        key = "z"
        type = "shell"
        command = "z ."
      '';
    };

    programs.zsh.shellAliases = {
      clauded = "claude --dangerously-skip-permissions";
      hp = "herdr session attach peersyst";
      hr = "herdr session attach reservame";
    };
  };
}

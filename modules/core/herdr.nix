{
  pkgs,
  username,
  ...
}:
{
  environment.systemPackages = [ pkgs.herdr ];

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

        [keys]
        goto = ""

        [[keys.command]]
        key = "prefix+g"
        type = "pane"
        command = "lazygit"

        [ui.sound]
        enabled = false
      '';
    };

    programs.zsh.shellAliases = {
      hn = "herdr session attach";
      hp = "herdr session attach peersyst";
    };
  };
}

{
  config,
  lib,
  username,
  ...
}:
lib.mkIf config.features.ghostty.enable {
  home-manager.users.${username} = {
    programs.zsh.shellAliases.ghostty-terminfo = "ghostty +copy-terminfo ssh";

    programs.ghostty = {
      enable = true;
      settings = {
        font-family = "JetBrains Mono Nerd Font";
        font-size = 20;
        background = "#1d1f21";
        background-opacity = 0.95;
        term = "xterm-ghostty";
        shell-integration = "zsh";
        shell-integration-features = "cursor,sudo,title";
      };
    };
  };
}

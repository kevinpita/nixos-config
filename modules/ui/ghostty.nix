{
  flake.modules.nixos.base = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.ghostty.terminfo ];
  };

  flake.modules.nixos.ghostty =
    { username, ... }:
    {
      home-manager.users.${username} = {
        programs.ghostty = {
          enable = true;
          settings = {
            font-family = "JetBrains Mono Nerd Font";
            font-size = 20;
            # theme-set links the selected desktop theme here.
            config-file = "?~/.local/state/theme/current/ghostty.conf";
            background-opacity = 0.95;
            term = "xterm-ghostty";
            shell-integration = "zsh";
            shell-integration-features = "cursor,sudo,title,ssh-env,ssh-terminfo";
            # Pass ctrl+shift+o to omp, which uses it to hide tool activity.
            keybind = [ "ctrl+shift+o=unbind" ];
          };
        };
      };
    };
}

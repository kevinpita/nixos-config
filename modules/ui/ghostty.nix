{
  flake.modules.nixos.ghostty =
    {
      username,
      ...
    }:
    {
      home-manager.users.${username} = {
        programs.zsh.initContent = ''
          copyterm() { infocmp -x xterm-ghostty | ssh "$1" -- tic -x -; }
        '';

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
    };

  # Ghostty owns its GNOME keybindings; this fragment merges into the gnome
  # aspect the same way modules/net/syncthing.nix contributes its indicator.
  flake.modules.nixos.gnome =
    { lib, username, ... }:
    {
      home-manager.users.${username}.dconf.settings = {
        "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = lib.mkAfter [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
        ];
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          name = "Open Terminal";
          binding = "<Super>Return";
          command = "ghostty";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
          name = "Open Pfium Herdr";
          binding = "F13";
          command = "ghostty -e herdr --remote pfium --remote-keybindings server";
        };
      };
    };
}

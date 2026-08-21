{
  flake.modules.nixos.gnome =
    { username, ... }:
    {
      home-manager.users.${username} = {
        dconf = {
          enable = true;
          settings = {
            "org/gnome/shell" = {
              disable-user-extensions = false;
              enabled-extensions = [
                "caffeine@patapon.info"
                "clipboard-history@alexsaveau.dev"
                "tailscale-status@maxgallup.github.com"
                "claude-usage@dvdstelt.github.io"
                "codex-usage@kevinpita.dev"
              ];
            };
            "org/gnome/shell/extensions/caffeine" = {
              show-indicator = true;
            };
            "org/gnome/desktop/interface" = {
              color-scheme = "prefer-dark";
              clock-show-seconds = true;
            };
            "org/gnome/shell/keybindings" = {
              show-screenshot-ui = [ "<Super>space" ];
            };
            "org/gnome/desktop/wm/keybindings" = {
              switch-input-source = [ ];
              switch-input-source-backward = [ ];
            };
            "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
            ];
            "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
              name = "Emoji Picker";
              binding = "<Super>period";
              command = "emoji-picker";
            };
          };
        };
      };
    };
}

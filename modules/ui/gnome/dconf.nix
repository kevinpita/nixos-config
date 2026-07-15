{
  flake.modules.nixos.gnome =
    {
      config,
      lib,
      username,
      ...
    }:
    let
      hmConfig = config.home-manager.users.${username};
      ghosttyEnabled = hmConfig.programs.ghostty.enable;
      dictationEnabled = lib.any (p: lib.getName p == "dictate-toggle") hmConfig.home.packages;
    in
    {
      home-manager.users.${username} = {
        dconf = {
          enable = true;
          settings = lib.mkMerge [
            {
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
              "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings =
                lib.optional ghosttyEnabled "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
                ++ [ "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/" ]
                ++ lib.optional dictationEnabled "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/";
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
                name = "Emoji Picker";
                binding = "<Super>period";
                command = "emoji-picker";
              };
            }
            (lib.mkIf ghosttyEnabled {
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
                name = "Open Terminal";
                binding = "<Super>Return";
                command = "ghostty";
              };
            })
            (lib.mkIf dictationEnabled {
              "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
                name = "Dictation";
                binding = "<Control><Alt>space";
                command = "/etc/profiles/per-user/${username}/bin/dictate-toggle";
              };
            })
          ];
        };
      };
    };
}

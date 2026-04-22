{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.desktop.enable {
  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm = {
      enable = true;
      wayland = true;
    };
    udev.packages = with pkgs; [ gnome-settings-daemon ];

    xserver = {
      enable = true;
      xkb.layout = "es";
    };

    displayManager.autoLogin = {
      enable = true;
      user = username;
    };

    libinput.enable = true;
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  home-manager.users.${username} = {
    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      nerd-fonts.jetbrains-mono

      gnome-pomodoro
      gnomeExtensions.caffeine
      gnomeExtensions.clipboard-history
      gnomeExtensions.tailscale-status
      wl-clipboard
    ];

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
              "claude-code-usage@haletran.com"
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
        }
        (lib.mkIf (config.features.ghostty.enable || config.features.alacritty.enable) {
          "org/gnome/settings-daemon/plugins/media-keys" = {
            custom-keybindings = [
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            ];
          };
          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
            name = "Open Terminal";
            binding = "<Super>Return";
            command = if config.features.ghostty.enable then "ghostty" else "alacritty";
          };
        })
      ];
    };
  };
}

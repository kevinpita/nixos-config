# Desktop feature - GNOME, X server, audio, alacritty, fonts
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.desktop.enable {
  # NixOS: GNOME desktop manager
  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm = {
      enable = true;
      wayland = true;
    };
    udev.packages = with pkgs; [ gnome-settings-daemon ];

    # X server configuration
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

  # NixOS: Audio via PipeWire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Home Manager: Desktop configuration
  home-manager.users.${username} = {
    # Font configuration
    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      nerd-fonts.jetbrains-mono

      # GNOME extensions and tools
      gnome-pomodoro
      gnomeExtensions.caffeine
      gnomeExtensions.clipboard-history
      gnomeExtensions.tailscale-status
      wl-clipboard
    ];

    # Alacritty terminal
    programs.alacritty = {
      enable = true;
      settings = {
        env.TERM = "xterm-256color";
        window.opacity = 0.95;
        font = {
          normal = {
            family = "JetBrains Mono Nerd Font";
            style = "Regular";
          };
          bold = {
            family = "JetBrains Mono Nerd Font";
            style = "Bold";
          };
          italic = {
            family = "JetBrains Mono Nerd Font";
            style = "Italic";
          };
          size = 20;
        };
      };
    };

    # GNOME dconf settings
    dconf = {
      enable = true;
      settings = {
        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = [
            "caffeine@patapon.info"
            "clipboard-history@alexsaveau.dev"
            "tailscale-status@maxgallup.github.com"
          ];
        };
        "org/gnome/shell/extensions/caffeine" = {
          show-indicator = true;
        };
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
        };
        "org/gnome/settings-daemon/plugins/media-keys" = {
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          ];
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          name = "Open Alacritty";
          binding = "<Super>Return";
          command = "alacritty";
        };
      };
    };
  };
}

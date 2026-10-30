{
  flake.modules.nixos.ui =
    {
      pkgs,
      username,
      ...
    }:
    {
      security.rtkit.enable = true;

      hardware.keyboard.qmk = {
        enable = true;
        keychronSupport = true;
      };

      services = {
        libinput.enable = true;
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          jack.enable = true;
          # Keep Bluetooth headsets on A2DP when an app opens the mic.
          wireplumber.extraConfig."51-bluetooth-a2dp"."wireplumber.settings" = {
            "bluetooth.autoswitch-to-headset-profile" = false;
          };
        };
        xserver.xkb = {
          layout = "es";
          variant = "deadtilde";
        };
      };

      # GTK 4.20+ on Wayland leaves dead keys and Compose to an input method.
      # No input method runs here, so the GTK built-in handling is required
      # for the deadtilde layout in GTK 4 apps such as Ghostty.
      environment.sessionVariables.GTK_IM_MODULE = "simple";

      home-manager.users.${username} = {
        fonts.fontconfig.enable = true;
        home.packages = with pkgs; [
          # Clipboard
          wl-clipboard

          # Fonts
          nerd-fonts.jetbrains-mono
          noto-fonts-color-emoji
        ];
      };
    };
}

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
        };
        xserver.xkb = {
          layout = "es";
          variant = "deadtilde";
        };
      };

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

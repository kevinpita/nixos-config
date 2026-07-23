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
        xserver.xkb.layout = "es";
        libinput.enable = true;
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          jack.enable = true;
        };
      };

      home-manager.users.${username} = {
        fonts.fontconfig.enable = true;
        home.packages = with pkgs; [
          nerd-fonts.jetbrains-mono
          noto-fonts-color-emoji
          wl-clipboard
        ];
      };
    };
}

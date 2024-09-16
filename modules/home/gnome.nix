{ pkgs, ... }:
{
  home.packages = with pkgs; [ gnomeExtensions.caffeine ];

  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = [ "caffeine@patapon.info" ];
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
}

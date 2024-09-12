{ pkgs, ... }:
{
  home.packages = with pkgs; [ gnomeExtensions.caffeine ];

  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        enabled-extensions = [ "caffeine@patapon.info" ];
      };
      "org/gnome/shell/extensions/caffeine" = {
        show-indicator = true;
      };
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };
  };
}

{ pkgs, ... }:
{
  services = {
    xserver = {
      desktopManager.gnome.enable = true;
      displayManager.gdm.enable = true;
    };

    udev.packages = with pkgs; [ gnome-settings-daemon ];
  };
}

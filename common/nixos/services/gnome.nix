{ pkgs, ... }:
{
  services = {
    xserver = {
      enable = true;
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
      xkb.layout = "es";
    };

    libinput.enable = true;

    udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];
  };

}

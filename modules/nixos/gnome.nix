{
  lib,
  config,
  pkgs,
  ...
}:
lib.mkIf config.gui.enable {
  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm = {
      enable = true;
      wayland = true;
    };

    udev.packages = with pkgs; [ gnome-settings-daemon ];
  };
}

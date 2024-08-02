{ pkgs, ... }:
{
  services = {
    power-profiles-daemon.enable = false;
    tlp = {
      enable = true;
      settings = {
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 45;
        START_CHARGE_THRESH_BAT1 = 75;
        STOP_CHARGE_THRESH_BAT1 = 80;
      };
    };
    xserver = {
      enable = true;
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
      xkb.layout = "es";
    };
    libinput.enable = true;
    udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];

    syncthing = {
      enable = true;
      user = "kevin";
      dataDir = "/home/kevin/";
      configDir = "/home/kevin/Documents/.config/syncthing";
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        devices = {
          "fium" = {
            id = "5MDWJ5N-EAY3RLI-BOKWRPA-SOVNZTM-FQRAPYW-CAH37PY-3ZP65ES-JKUXJQR";
          };
          "Pixel 5" = {
            id = "QEW4Z4J-EJE5RDC-UNKAH7Q-NBHVW4L-TAGE4R6-AHQKYWJ-R64A2RR-2ODRBAM";
          };
        };
        folders = {
          "afnt2-e5u36" = {
            path = "/home/kevin/keepass";
            devices = [
              "fium"
              "Pixel 5"
            ];
          };
        };
      };
    };
  };

}

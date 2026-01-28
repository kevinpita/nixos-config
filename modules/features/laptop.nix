# Laptop feature - TLP power management and firmware updates
{ config, lib, ... }:
lib.mkIf config.features.laptop.enable {
  services = {
    # Disable power-profiles-daemon as it conflicts with TLP
    power-profiles-daemon.enable = false;

    # TLP for battery management
    tlp = {
      enable = true;
      settings = {
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 45;
        START_CHARGE_THRESH_BAT1 = 75;
        STOP_CHARGE_THRESH_BAT1 = 80;
      };
    };

    # Firmware updates
    fwupd.enable = true;
  };
}

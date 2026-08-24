{
  lib,
  pkgs,
  username,
  ...
}:
{
  programs.nixos-hyprland.hostConfig = "/home/${username}/nixos-config/hosts/t14g6/hyprland.lua";

  hardware.bluetooth.enable = true;

  environment.etc."systemd/system-sleep/reset-elan-touchpad" = {
    mode = "0755";
    source = pkgs.writeShellScript "reset-elan-touchpad" ''
      if [ "$1" != post ]; then
        exit 0
      fi

      driver=/sys/bus/i2c/drivers/i2c_hid_acpi
      device=i2c-ELAN0678:00

      if [ ! -e "$driver/$device" ]; then
        exit 0
      fi

      printf '%s' "$device" > "$driver/unbind"
      ${lib.getExe' pkgs.coreutils "sleep"} 0.5
      printf '%s' "$device" > "$driver/bind"
    '';
  };

  services = {
    logind.settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
    };
    upower.enable = true;
  };

  users.users.${username}.extraGroups = [ "input" ];
}

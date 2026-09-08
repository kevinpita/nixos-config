{ config, ... }:
{
  flake.modules.nixos."hosts/amdep" =
    { username, pkgs, ... }:
    {
      imports = [
        ../../hosts/amdep/disko-config.nix
        ../../hosts/amdep/hardware-configuration.nix

        config.flake.modules.nixos.desktop
        config.flake.modules.nixos.herdr-ssh-client
        config.flake.modules.nixos.qemu
      ];

      hardware.bluetooth.enable = true;

      programs.nixos-hyprland.hostConfig = "/home/${username}/nixos-config/hosts/amdep/hyprland.lua";

      boot.kernelPackages = pkgs.linuxPackages_latest;

      # Windows uses local time in the hardware clock.
      time.hardwareClockInLocalTime = true;
      boot.loader.grub.useOSProber = true;
    };
}

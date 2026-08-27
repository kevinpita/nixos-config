{ config, ... }:
{
  flake.modules.nixos."hosts/amdep" =
    { username, ... }:
    {
      imports = [
        ../../hosts/amdep/disko-config.nix
        ../../hosts/amdep/hardware-configuration.nix

        config.flake.modules.nixos.desktop
        config.flake.modules.nixos.vm
      ];

      programs.nixos-hyprland.hostConfig = "/home/${username}/nixos-config/hosts/amdep/hyprland.lua";

      # Dual-boot support
      boot.loader.grub.useOSProber = true;
    };
}

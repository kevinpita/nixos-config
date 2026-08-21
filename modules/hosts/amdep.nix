{ config, ... }:
{
  flake.modules.nixos."hosts/amdep" = {
    imports = [
      ../../hosts/amdep/disko-config.nix
      ../../hosts/amdep/hardware-configuration.nix

      ../../hosts/amdep/monitors.nix

      config.flake.modules.nixos.desktop
      config.flake.modules.nixos.dictation
      config.flake.modules.nixos.vm
    ];

    # Dual-boot support
    boot.loader.grub.useOSProber = true;
  };
}

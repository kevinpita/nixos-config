{ config, inputs, ... }:
{
  flake.modules.nixos."hosts/t480s" = {
    imports = [
      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480

      ../../hosts/t480s/disko-config.nix
      ../../hosts/t480s/hardware-configuration.nix

      ../../hosts/t480s/syncthing.nix
      ../../hosts/t480s/tlp.nix

      config.flake.modules.nixos."roles/desktop"
    ];

    # Dual-boot support
    uefiOSProber = true;
  };
}

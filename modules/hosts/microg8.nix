{ config, ... }:
{
  flake.modules.nixos."hosts/microg8" = {
    imports = [
      ../../hosts/microg8/disko-config.nix
      ../../hosts/microg8/drives.nix
      ../../hosts/microg8/hardware-configuration.nix
      ../../hosts/microg8/networking.nix

      ../../hosts/microg8/syncthing.nix

      config.flake.modules.nixos.server
    ];

    bootloader.mode = "bios";
  };
}

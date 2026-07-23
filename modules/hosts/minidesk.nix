{ config, ... }:
{
  flake.modules.nixos."hosts/minidesk".imports = [
    ../../hosts/minidesk/disko-config.nix
    ../../hosts/minidesk/hardware-configuration.nix

    config.flake.modules.nixos."roles/server"
  ];
}

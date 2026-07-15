{ config, ... }:
{
  flake.modules.nixos."hosts/hulk" = {
    imports = [
      ../../hosts/hulk/disko-config.nix
      ../../hosts/hulk/hardware-configuration.nix
      ../../hosts/hulk/networking.nix

      ../../hosts/hulk/syncthing.nix

      config.flake.modules.nixos."roles/server"
      config.flake.modules.nixos.k3s
      config.flake.modules.nixos.kubernetes
    ];
  };
}

{ config, ... }:
{
  flake.modules.nixos."hosts/minidesk".imports = [
    ../../hosts/minidesk/disko-config.nix
    ../../hosts/minidesk/hardware-configuration.nix

    config.flake.modules.nixos.server
    config.flake.modules.nixos.aws
    config.flake.modules.nixos.kubernetes
    config.flake.modules.nixos.mosh
    config.flake.modules.nixos.moshi
    config.flake.modules.nixos.herdr-remote-host
    config.flake.modules.nixos.incus
    config.flake.modules.nixos.work-cloud
    config.flake.modules.nixos.work-github
  ];
}

{ config, ... }:
{
  flake.modules.nixos."roles/server".imports = with config.flake.modules.nixos; [
    base
    ai
    development
    docker
    git
    syncthing
    tailscale
  ];
}

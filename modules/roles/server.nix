{ config, ... }:
{
  flake.modules.nixos.server.imports = with config.flake.modules.nixos; [
    base
    ai
    development
    docker
    git
    syncthing
    tailscale
  ];
}

{ config, ... }:
{
  flake.modules.nixos."roles/desktop".imports = with config.flake.modules.nixos; [
    base
    ai
    aws
    browsers
    communication
    desktop
    development
    docker
    ghostty
    git
    gnome
    kubernetes
    multimedia
    printing-3d
    sops-admin
    syncthing
    tailscale
    work
    zed
  ];
}

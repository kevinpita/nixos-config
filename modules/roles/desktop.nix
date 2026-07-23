{ config, ... }:
{
  flake.modules.nixos.desktop.imports = with config.flake.modules.nixos; [
    base
    ai
    aws
    browsers
    communication
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
    ui
    work
    zed
  ];
}

{ config, ... }:
{
  flake.modules.nixos = {
    workstation.imports = with config.flake.modules.nixos; [
      base
      ai
      aws
      browsers
      communication
      development
      docker
      file-sharing
      ghostty
      git
      kubernetes
      multimedia
      printing-3d
      security
      sops-admin
      syncthing
      tailscale
      ui
      work
      zed
    ];

    desktop.imports = with config.flake.modules.nixos; [
      workstation
      gnome
    ];

    "hyprland-desktop".imports = with config.flake.modules.nixos; [
      workstation
      hyprland
    ];
  };
}

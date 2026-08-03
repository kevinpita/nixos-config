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
      ghostty
      git
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

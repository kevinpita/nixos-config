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
      syncthing
      tailscale
      ui
      work-cloud
      work-servers
      zed
    ];

    desktop.imports = with config.flake.modules.nixos; [
      workstation
      gnome
    ];
  };
}

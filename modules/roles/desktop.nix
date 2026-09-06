{ config, inputs, ... }:
{
  flake.modules.nixos = {
    workstation.imports = with config.flake.modules.nixos; [
      base
      ai
      aws
      browsers
      communication
      development
      podman
      file-sharing
      ghostty
      git
      kubernetes
      multimedia
      printing-3d
      security
      tailscale
      ui
      work-cloud
      work-servers
      zed
    ];

    desktop.imports = [
      config.flake.modules.nixos.workstation
      config.flake.modules.nixos.dictation
      inputs.nixos-hyprland.nixosModules.default
    ];
  };
}

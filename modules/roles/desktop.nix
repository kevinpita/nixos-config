{ config, inputs, ... }:
{
  flake.modules.nixos = {
    workstation.imports = with config.flake.modules.nixos; [
      ai
      aws
      base
      browsers
      communication
      development
      file-sharing
      ghostty
      git
      kubernetes-client
      multimedia
      podman
      printing-3d
      productivity
      security
      tailscale
      ui
      work-cloud
      work-servers
      zed
    ];

    desktop.imports = [
      config.flake.modules.nixos.dictation
      config.flake.modules.nixos.workstation
      inputs.nixos-hyprland.nixosModules.default
    ];
  };
}

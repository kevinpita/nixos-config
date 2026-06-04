{ inputs, ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix

    ./monitors.nix
    ./syncthing.nix
    ./tlp.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen6
  ];
  features = {
    ai.enable = true;
    aws.enable = true;
    browsers.enable = true;
    communication.enable = true;
    desktop.enable = true;
    development.enable = true;
    docker.enable = true;
    ghostty.enable = true;
    git.enable = true;
    gnome.enable = true;
    kubernetes.enable = true;
    multimedia.enable = true;
    printing-3d.enable = true;
    sops-admin.enable = true;
    syncthing.enable = true;
    tailscale.enable = true;
    virtualization.incus.enable = true;
    virtualization.vm.enable = true;
    work.enable = true;
    zed.enable = true;
  };
}

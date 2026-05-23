{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix

    ./monitors.nix
    ./syncthing.nix
  ];

  # Dual-boot support
  uefiOSProber = true;

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
    kubernetes.enable = true;
    multimedia.enable = true;
    printing-3d.enable = true;
    sops-admin.enable = true;
    syncthing.enable = true;
    tailscale.enable = true;
    virtualization.virt-manager.enable = true;
    work.enable = true;
    zed.enable = true;
  };
}

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
    desktop.enable = true;
    ghostty.enable = true;
    git.enable = true;
    development.enable = true;
    zed.enable = true;
    docker.enable = true;
    browsers.enable = true;
    multimedia.enable = true;
    communication.enable = true;
    syncthing.enable = true;
    printing-3d.enable = true;
    kubernetes.enable = true;
    aws.enable = true;
    ai.enable = true;
    tailscale.enable = true;
    sops-admin.enable = true;
    work.enable = true;
  };
}

{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix

    ./syncthing.nix
    ./tlp.nix
  ];
  features = {
    desktop.enable = true;
    ghostty.enable = true;
    git.enable = true;
    development.enable = true;
    devops.enable = true;
    zed.enable = true;
    docker.enable = true;
    virtualization.enable = true;
    browsers.enable = true;
    multimedia.enable = true;
    communication.enable = true;
    syncthing.enable = true;
    printing-3d.enable = true;
    kubernetes.enable = true;
    aws.enable = true;
    ai.enable = true;
  };
}

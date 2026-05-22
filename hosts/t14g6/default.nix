{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix

    ./monitors.nix
    ./syncthing.nix
    ./tlp.nix
  ];
  features = {
    desktop.enable = true;
    ghostty.enable = true;
    git.enable = true;
    development.enable = true;
    devops.enable = true;
    editors.zed.enable = true;
    editors.vscode.enable = false;
    docker.enable = true;
    virtualization.virt-manager.enable = true;
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
  };
}

{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix
    ./networking.nix

    ./syncthing.nix
  ];

  features = {
    ai.enable = true;
    development.enable = true;
    docker.enable = true;
    git.enable = true;
    syncthing.enable = true;
    tailscale.enable = true;

    k3s.enable = true;
    kubernetes.enable = true;
  };
}

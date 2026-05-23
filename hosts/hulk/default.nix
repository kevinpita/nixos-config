{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix
    ./networking.nix

    ./syncthing.nix
  ];

  features = {
    docker.enable = true;
    syncthing.enable = true;
    tailscale.enable = true;

    k3s.enable = true;
    kubernetes.enable = true;
  };
}

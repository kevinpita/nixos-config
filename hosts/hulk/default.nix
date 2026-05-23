{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix
    ./networking.nix

    ./syncthing.nix
  ];

  features = {
    auto-update.enable = false;
    docker.enable = true;
    syncthing.enable = true;
    tailscale.enable = true;

    k3s.enable = true;
    kubernetes.enable = true;
  };
}

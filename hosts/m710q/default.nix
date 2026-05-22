{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix

    ./syncthing.nix
  ];

  features = {
    docker.enable = true;
    tailscale.enable = true;
    syncthing.enable = true;
  };
}

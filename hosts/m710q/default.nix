{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix

    # Host-specific syncthing additions (extra devices)
    ./syncthing.nix
  ];

  features = {
    ssh-server.enable = true;
    syncthing.enable = true;
  };
}

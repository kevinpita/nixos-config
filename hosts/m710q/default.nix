{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix

    ./syncthing.nix
  ];

  features = {
    ssh-server.enable = true;
    syncthing.enable = true;
  };
}

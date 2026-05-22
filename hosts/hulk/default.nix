{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix
    ./networking.nix

    ./syncthing.nix
  ];

  bootloader.mode = "bios";

  features = {
    docker.enable = true;
    ssh-server.enable = true;
    syncthing.enable = true;
    auto-update.enable = false;
  };
}

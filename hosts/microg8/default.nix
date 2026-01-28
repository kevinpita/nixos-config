{ ... }:
{
  imports = [
    ./disko-config.nix
    ./drives.nix
    ./hardware-configuration.nix
    ./networking.nix

    # Host-specific syncthing additions (extra devices, guiAddress)
    ./syncthing.nix
  ];

  bootloader.mode = "bios";

  features = {
    ssh-server.enable = true;
    syncthing.enable = true;
    auto-update.enable = true;
  };
}

{ ... }:
{
  imports = [
    ./disko-config.nix
    ./drives.nix
    ./hardware-configuration.nix
    ./networking.nix
    ./update.nix

    ../../modules/nixos

    ./syncthing.nix
  ];

  bootloader.mode = "bios";
  gui.enable = false;
}

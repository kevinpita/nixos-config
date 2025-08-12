{ ... }:
{
  imports = [
    ./disko-config.nix
    ./drives.nix
    ./hardware-configuration.nix
    ./networking.nix
    ./update.nix

    ../../modules/nixos
    ../../modules/nixos/bootloader-bios.nix

    ./syncthing.nix
  ];

}

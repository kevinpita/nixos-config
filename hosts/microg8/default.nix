{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix
    ./drives.nix
    ./networking.nix

    ../../modules/nixos
    ../../modules/nixos/bootloader-bios.nix

    ./syncthing.nix
  ];

}

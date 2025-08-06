{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix

    ../../modules/nixos
    ../../modules/nixos/bootloader-uefi.nix

    ./syncthing.nix
  ];
}

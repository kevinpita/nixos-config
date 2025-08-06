{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix
    ./drives.nix

    ../../modules/nixos
    ../../modules/nixos/bootloader-bios.nix
    ../../modules/nixos/ssh.nix

    ./syncthing.nix
  ];

  boot.loader.grub.device = "/dev/sdc";
}

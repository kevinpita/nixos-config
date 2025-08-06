{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix
    ./drives.nix

    ../../modules/nixos
    ../../modules/nixos/ssh.nix

    ./syncthing.nix
  ];
}

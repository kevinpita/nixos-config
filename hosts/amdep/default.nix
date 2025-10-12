{ ... }:
{
  imports = [
    ./disko-config.nix
    ./hardware-configuration.nix

    ../../modules/nixos

    ./syncthing.nix
  ];

  config = {
    uefiOSProber = true;
  };
}

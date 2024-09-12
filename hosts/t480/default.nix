{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480

    ./disko-config.nix
    ./hardware-configuration.nix

    ../../modules/nixos

    ./syncthing.nix
    ./tlp.nix
  ];
}

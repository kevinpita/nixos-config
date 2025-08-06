{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480

    ./disko-config.nix
    ./hardware-configuration.nix

    ../../modules/nixos
    ../../modules/nixos/bootloader-uefi.nix

    ./syncthing.nix
    ./tlp.nix
    ./fwupdmgr.nix
  ];
}

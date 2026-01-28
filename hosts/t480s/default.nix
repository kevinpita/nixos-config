{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480

    ./disko-config.nix
    ./hardware-configuration.nix

    # Host-specific syncthing additions (extra devices)
    ./syncthing.nix
  ];

  # Dual-boot support
  uefiOSProber = true;

  features = {
    desktop.enable = true;
    development.enable = true;
    virtualization.enable = true;
    browsers.enable = true;
    multimedia.enable = true;
    communication.enable = true;
    syncthing.enable = true;
    printing-3d.enable = true;
    laptop.enable = true;
  };
}

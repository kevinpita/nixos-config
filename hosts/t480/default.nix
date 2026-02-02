{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480

    ./disko-config.nix
    ./hardware-configuration.nix

    ./syncthing.nix
    ./tlp.nix
  ];

  features = {
    desktop.enable = true;
    development.enable = true;
    virtualization.enable = true;
    browsers.enable = true;
    multimedia.enable = true;
    communication.enable = true;
    syncthing.enable = true;
    printing-3d.enable = true;
  };
}

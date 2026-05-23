{ ... }:
{
  imports = [
    ./disko-config.nix
    ./drives.nix
    ./hardware-configuration.nix
    ./networking.nix

    ./syncthing.nix
  ];

  bootloader.mode = "bios";

  features = {
    docker.enable = true;
    tailscale.enable = true;
    syncthing.enable = true;
  };
}

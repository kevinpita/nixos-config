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
    ai.enable = true;
    development.enable = true;
    docker.enable = true;
    git.enable = true;
    syncthing.enable = true;
    tailscale.enable = true;
  };
}

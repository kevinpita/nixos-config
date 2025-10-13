{ lib, ... }:
{
  options.gui.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable GUI support";
  };

  imports = [
    ./audio.nix
    ./docker.nix
    ./gnome.nix
    ./networking.nix
    ./nh.nix
    ./programs.nix
    ./shell.nix
    ./ssh.nix
    ./syncthing.nix
    ./system.nix
    ./user.nix
    ./vm.nix
    ./xserver.nix
  ];
}

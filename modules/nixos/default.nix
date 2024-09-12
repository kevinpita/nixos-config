{ lib, gui, ... }:
{
  imports =
    [
      ./bootloader.nix
      ./docker.nix
      ./networking.nix
      ./nh.nix
      ./shell.nix
      ./syncthing.nix
      ./system.nix
      ./user.nix
      ./vm.nix
      ./programs.nix
    ]
    ++ (lib.optionals gui [
      ./audio.nix
      ./gnome.nix
      ./xserver.nix
    ]);
}

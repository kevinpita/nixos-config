{
  pkgs,
  username,
  hostname,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix

    (import ../../common/nixos { inherit pkgs username hostname; })
    ../../common/nixos/services/gnome.nix
    ../../common/nixos/services/tailscale.nix

    ./services/tlp.nix
    (import ./services/syncthing.nix { inherit pkgs username; })
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username} = import ./home.nix { inherit pkgs username; };
  };
}

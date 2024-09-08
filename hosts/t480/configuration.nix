{
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix

    ../../common/nixos
    ../../common/nixos/services/gnome.nix
    ../../common/nixos/services/tailscale.nix
    ../../common/nixos/vm.nix

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

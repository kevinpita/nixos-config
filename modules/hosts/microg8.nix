{ config, ... }:
let
  inherit (config.flake.modules.nixos) server;
in
{
  flake.modules.nixos."hosts/microg8" =
    { pkgs, ... }:
    {
      imports = [
        ../../hosts/microg8/disko-config.nix
        ../../hosts/microg8/hardware-configuration.nix
        server
      ];

      boot.loader.grub = {
        efiSupport = false;
        theme = null;
      };
      boot.kernelPackages = pkgs.linuxPackages_latest;

      services.smartd.defaults.monitored = "-a -s (S/../.././01|L/../../3/02)";

      networking = {
        networkmanager.enable = false;
        useDHCP = true;
      };
    };
}

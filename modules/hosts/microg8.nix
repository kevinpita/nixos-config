{ config, ... }:
let
  inherit (config.flake.modules.nixos) server;
in
{
  flake.modules.nixos."hosts/microg8" =
    { ... }:
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

      services.btrfs.autoScrub = {
        enable = true;
        fileSystems = [
          "/"
          "/storage/500gb"
          "/storage/1tb"
        ];
        interval = "weekly";
      };
      services.smartd.defaults.monitored = "-a -s (S/../.././01|L/../../3/02)";

      networking = {
        networkmanager.enable = false;
        useDHCP = true;
      };
    };
}

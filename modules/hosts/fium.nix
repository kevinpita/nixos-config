{ config, ... }:
{
  flake.modules.nixos."hosts/fium" =
    { lib, ... }:
    {
      imports = [
        ../../hosts/fium/disko-config.nix
        ../../hosts/fium/hardware-configuration.nix
        config.flake.modules.nixos.kubernetes-client
        config.flake.modules.nixos.server
        config.flake.modules.nixos.selfhosted
      ];

      selfhosted.metrics = {
        tailnetDomain = "tail235c8.ts.net";
        extraNodeTargets = [ ];
        telegram.enable = true;
      };

      boot.loader = {
        efi.canTouchEfiVariables = lib.mkForce false;
        grub = {
          efiSupport = lib.mkForce false;
          devices = lib.mkForce [ "/dev/disk/by-id/ata-SanDisk_SDSSDH3_500G_2105F6451107" ];
          theme = lib.mkForce null;
        };
      };

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      boot.supportedFilesystems = [ "zfs" ];
      boot.zfs = {
        devNodes = "/dev/disk/by-id";
        extraPools = [
          "downloads"
          "seagate3x4"
        ];
        forceImportAll = false;
        forceImportRoot = false;
      };
      networking = {
        hostId = "44dc8051";
        networkmanager.enable = lib.mkForce false;
        useDHCP = false;
        interfaces.eno1.ipv4.addresses = [
          {
            address = "192.168.1.110";
            prefixLength = 24;
          }
        ];
        defaultGateway = "192.168.1.1";
      };
    };
}

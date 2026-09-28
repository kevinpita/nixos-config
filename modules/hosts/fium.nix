{ config, ... }:
let
  inherit (config.flake.modules.nixos)
    hermes-vm
    kubernetes-server
    moshi
    nix-cache-server
    selfhosted
    selfhosted-secrets
    ;
in
{
  flake.modules.nixos."hosts/fium" =
    { config, ... }:
    {
      imports = [
        ../../hosts/fium/disko-config.nix
        ../../hosts/fium/hardware-configuration.nix
        hermes-vm
        kubernetes-server
        moshi
        nix-cache-server
        selfhosted
        selfhosted-secrets
      ];

      nixCache.publicKey = "fium-cache-1:Aeu01Pv7XdRgBN33KuV5B/DXzeAwpo5nLwd3Kh79fVc=";

      selfhosted.web = {
        domain = "kevinpita.com";
        tailscaleIPv4 = "100.85.41.60";
      };

      boot.loader.grub = {
        efiSupport = false;
        theme = null;
      };

      services.openssh = {
        enable = true;
        openFirewall = false;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      services.zfs.autoScrub = {
        enable = true;
        interval = "Sun *-*-* 04:00:00";
        # An empty list includes every imported pool.
        pools = [ ];
      };

      # Add weekly extended tests to the shared daily short tests.
      # Keep extended tests away from the Sunday ZFS scrub.
      services.smartd.defaults.monitored = "-a -s (S/../.././01|L/../../3/02)";

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
        firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [ 22 ];
        hostId = "44dc8051";
        networkmanager.enable = false;
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

{ config, ... }:
let
  inherit (config.flake.modules.nixos)
    hermes-vm
    ilofan
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
        ilofan
        kubernetes-server
        moshi
        nix-cache-server
        selfhosted
        selfhosted-secrets
      ];

      # iLO 4 of this ProLiant ML310e Gen8 v2. Both keys are public.
      services.ilofan.settings = {
        host = "192.168.1.148";
        username = "Administrator";
        hostKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDR2h9lzGl0uVI/iXmxkc3i3oLWgEoc/Y62Lo2vtKpFKkVv8H6GdEPAfJLtbrrOvWauhjMbY8OsFiHsrFFPTe5ukQS437DT8369y87GmjYPo8295dDh5c+4oLo0YBhUOq9HlmGHHv7jv9r3LGCgKT+L0AmsNxxotMxJaa6enAugQrWzepyrbKHwFOGrk+lo4HPX/h0/dAvFE97Gv++j80HdpXM0nRg2u3w2B+6zS3ZY7BrX/xXDZ49ANkVWhgdxnG80VFP2VxcNWsYTI0XWA+e48g6OzGIizd3tGsE774pxumkvNGjslgR0lf7w5/rjBEhKQbIonWqciT7Uyd39Xly/";
        tlsFingerprint = "2D:F7:54:F6:D9:2D:2E:DC:41:18:FB:0D:B8:B8:0F:9D:39:AC:8F:72:EA:E0:C0:98:8D:18:72:3B:69:7F:F0:FF";
        mode = "control";
        # Very quiet: hold the 9 % floor until the CPU or inlet gets warm.
        # Warning and danger thresholds still raise the fans.
        curves = {
          "02-CPU" = [
            {
              temp = 50;
              percent = 9;
            }
            {
              temp = 54;
              percent = 15;
            }
            {
              temp = 58;
              percent = 30;
            }
          ];
          "01-Inlet Ambient" = [
            {
              temp = 28;
              percent = 9;
            }
            {
              temp = 31;
              percent = 15;
            }
            {
              temp = 34;
              percent = 30;
            }
          ];
        };
      };

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

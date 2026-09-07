{ config, ... }:
{
  flake.modules.nixos.hermes-vm = {
    imports = [ config.flake.modules.nixos.incus ];

    virtualisation.incus.preseed = {
      storage_pools = [
        {
          name = "hermes";
          driver = "dir";
        }
      ];
      networks = [
        {
          name = "hermesbr0";
          type = "bridge";
          config = {
            "ipv4.address" = "10.77.0.1/24";
            "ipv4.nat" = "true";
            "ipv6.address" = "none";
          };
        }
      ];
      profiles = [
        {
          name = "hermes";
          config = {
            "boot.autostart" = "true";
            "limits.cpu" = "2";
            "limits.memory" = "4GiB";
          };
          devices = {
            eth0 = {
              name = "eth0";
              network = "hermesbr0";
              type = "nic";
            };
            root = {
              path = "/";
              pool = "hermes";
              size = "40GiB";
              type = "disk";
            };
          };
        }
      ];
    };

    networking.firewall.interfaces.hermesbr0 = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [
        53
        67
      ];
    };
  };
}

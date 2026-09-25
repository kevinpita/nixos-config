{
  flake.modules.nixos.base =
    { hostname, pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        curl
        ethtool
        tcpdump
        wget
      ];

      networking = {
        hostName = hostname;
        networkmanager = {
          enable = true;
          settings.connectivity = {
            enabled = true;
            uri = "http://nmcheck.gnome.org/check_network_status.txt";
            interval = 300;
          };
        };
        nameservers = [
          "1.1.1.1"
          "1.0.0.1"
        ];
      };
    };

  # Don't block boot on Wi-Fi: a slow or failing association otherwise delays
  # network-online.target (and everything ordered after it, e.g. incus).
  flake.modules.nixos.workstation = {
    systemd.services.NetworkManager-wait-online.enable = false;
  };
}

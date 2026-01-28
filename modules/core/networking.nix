# Core networking module - network configuration and Tailscale
{ hostname, ... }:
{
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

  services.tailscale.enable = true;
}

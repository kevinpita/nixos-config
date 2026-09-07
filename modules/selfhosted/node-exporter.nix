{
  flake.modules.nixos.node-exporter =
    { config, ... }:
    {
      assertions = [
        {
          assertion = config.services.tailscale.enable && config.networking.firewall.enable;
          message = "node-exporter requires Tailscale and the host firewall.";
        }
      ];

      services.prometheus.exporters.node = {
        enable = true;
        openFirewall = false;
        enabledCollectors = [ "systemd" ];
      };

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
        config.services.prometheus.exporters.node.port
      ];
    };
}

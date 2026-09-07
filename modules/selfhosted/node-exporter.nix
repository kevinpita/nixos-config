{
  flake.modules.nixos.node-exporter =
    { config, lib, ... }:
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

      systemd.services.prometheus-node-exporter.serviceConfig.ProtectHome = lib.mkForce "read-only";

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
        config.services.prometheus.exporters.node.port
      ];
    };
}

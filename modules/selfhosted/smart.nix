{
  flake.modules.nixos.node-exporter =
    { config, lib, ... }:
    {
      services.prometheus.exporters.smartctl = {
        enable = lib.mkDefault config.services.smartd.enable;
        openFirewall = false;
        # Read health data without starting self-tests. smartd owns the schedule.
        maxInterval = "5m";
      };

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts =
        lib.mkIf config.services.prometheus.exporters.smartctl.enable
          [
            config.services.prometheus.exporters.smartctl.port
          ];
    };
}

{
  flake.modules.nixos.node-exporter =
    { config, lib, ... }:
    {
      services.prometheus.exporters.zfs = {
        enable = lib.mkDefault (config.boot.supportedFilesystems.zfs or false);
        openFirewall = false;
      };

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts =
        lib.mkIf config.services.prometheus.exporters.zfs.enable
          [
            config.services.prometheus.exporters.zfs.port
          ];
    };
}

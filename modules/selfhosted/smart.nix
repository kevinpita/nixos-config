{
  flake.modules.nixos.node-exporter =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      services.prometheus.exporters.smartctl = {
        enable = lib.mkDefault config.services.smartd.enable;
        openFirewall = false;
        # Read health data without starting self-tests. smartd owns the schedule.
        maxInterval = "5m";
      };

      # NixOS grants this ACL on add. Also handle change events so udevadm
      # trigger can grant access to existing controllers without a reboot.
      services.udev.extraRules = lib.mkIf config.services.prometheus.exporters.smartctl.enable ''
        ACTION=="change", SUBSYSTEM=="nvme", KERNEL=="nvme[0-9]*", RUN+="${pkgs.acl}/bin/setfacl -m g:smartctl-exporter-access:rw /dev/$kernel"
      '';

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts =
        lib.mkIf config.services.prometheus.exporters.smartctl.enable
          [
            config.services.prometheus.exporters.smartctl.port
          ];
    };
}

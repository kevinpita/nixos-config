{
  flake.modules.nixos.node-exporter =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Export recorded self-test age and result. Keep the read time as a
      # freshness guard so cached data cannot hide failed disk reads.
      nixpkgs.overlays = [
        (_final: prev: {
          prometheus-smartctl-exporter = prev.prometheus-smartctl-exporter.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ../../packages/prometheus-smartctl-exporter/self-test-history.patch
            ];
          });
        })
      ];

      services.prometheus.exporters.smartctl = {
        enable = lib.mkDefault config.services.smartd.enable;
        openFirewall = false;
        # Read health data without starting self-tests. smartd owns the schedule.
        maxInterval = "5m";
      };

      # NixOS grants this ACL on add. Also cover controllers that existed
      # before the udev rules were installed or were recreated at boot.
      services.udev.extraRules = lib.mkIf config.services.prometheus.exporters.smartctl.enable ''
        ACTION=="change", SUBSYSTEM=="nvme", KERNEL=="nvme[0-9]*", RUN+="${pkgs.acl}/bin/setfacl -m g:smartctl-exporter-access:rw /dev/$kernel"
      '';
      systemd.services.prometheus-smartctl-exporter.serviceConfig.ExecStartPre =
        lib.mkIf config.services.prometheus.exporters.smartctl.enable "+${pkgs.writeShellScript "grant-smartctl-nvme-access" ''
          for device in /dev/nvme[0-9]*; do
            if [[ "$device" =~ ^/dev/nvme[0-9]+$ ]]; then
              ${pkgs.acl}/bin/setfacl -m g:smartctl-exporter-access:rw "$device"
            fi
          done
        ''}";

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts =
        lib.mkIf config.services.prometheus.exporters.smartctl.enable
          [
            config.services.prometheus.exporters.smartctl.port
          ];
    };
}

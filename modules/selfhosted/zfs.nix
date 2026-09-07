{
  flake.modules.nixos.node-exporter =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      scrubDirectory = "/var/lib/zfs-scrub-metrics";
    in
    {
      services.prometheus.exporters.zfs = {
        enable = lib.mkDefault (config.boot.supportedFilesystems.zfs or false);
        openFirewall = false;
      };

      services.prometheus.exporters.node.extraFlags =
        lib.mkIf config.services.prometheus.exporters.zfs.enable
          [
            "--collector.textfile.directory=${scrubDirectory}"
          ];

      systemd.services.zfs-scrub-metrics = lib.mkIf config.services.prometheus.exporters.zfs.enable {
        description = "Collect completed ZFS scrub dates";
        after = [ "zfs.target" ];
        path = [ config.boot.zfs.package ];
        serviceConfig = {
          Type = "oneshot";
          User = config.services.prometheus.exporters.node.user;
          Group = config.services.prometheus.exporters.node.group;
          StateDirectory = "zfs-scrub-metrics";
          StateDirectoryMode = "0750";
          UMask = "0027";
          TimeoutStartSec = "30s";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
        script = ''
          ${lib.getExe pkgs.python3} ${./zfs-scrub-metrics.py} "$STATE_DIRECTORY"
        '';
      };

      systemd.timers.zfs-scrub-metrics = lib.mkIf config.services.prometheus.exporters.zfs.enable {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = "1min";
          AccuracySec = "10s";
        };
      };

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts =
        lib.mkIf config.services.prometheus.exporters.zfs.enable
          [
            config.services.prometheus.exporters.zfs.port
          ];
    };
}

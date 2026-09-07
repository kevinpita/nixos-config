{
  flake.modules.nixos.node-exporter =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      exporter = config.services.prometheus.exporters.node;
      home = config.users.users.${username}.home;
      storageMetrics = "${lib.getExe pkgs.python3} ${./storage-metrics.py}";
      commonService = {
        Type = "oneshot";
        Group = exporter.group;
        StateDirectoryMode = "0750";
        UMask = "0027";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
      };
    in
    {
      services.prometheus.exporters.node.extraFlags = [
        "--collector.textfile.directory=/var/lib/node-disk-metrics"
        "--collector.textfile.directory=/var/lib/node-folder-metrics"
      ];

      systemd.services.node-disk-metrics = {
        description = "Collect physical disk and unique filesystem capacity";
        path = [ pkgs.util-linux ];
        serviceConfig = commonService // {
          User = exporter.user;
          StateDirectory = "node-disk-metrics";
          TimeoutStartSec = "30s";
        };
        script = ''
          ${storageMetrics} disks "$STATE_DIRECTORY"
        '';
      };
      systemd.timers.node-disk-metrics = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = "1min";
          AccuracySec = "10s";
        };
      };

      systemd.services.node-folder-metrics = {
        description = "Rank system and home folder allocation";
        path = [
          pkgs.util-linux
          pkgs.coreutils
        ];
        serviceConfig = commonService // {
          User = "root";
          StateDirectory = "node-folder-metrics";
          TimeoutStartSec = "1h";
          Nice = 19;
          IOSchedulingClass = "idle";
          CPUSchedulingPolicy = "idle";
          PrivateDevices = true;
          CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
        };
        script = ''
          ${storageMetrics} folders "$STATE_DIRECTORY" ${lib.escapeShellArg home}
        '';
      };
      systemd.timers.node-folder-metrics = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2min";
          OnUnitActiveSec = "6h";
          RandomizedDelaySec = "10min";
          AccuracySec = "1min";
        };
      };
    };
}

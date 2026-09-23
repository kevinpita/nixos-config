{
  flake.modules.nixos.selfhosted =
    {
      config,
      ciMode,
      lib,
      pkgs,
      ...
    }:
    let
      matrixEnabled = !ciMode;
      alertmanager = config.services.prometheus.alertmanager;
      filesystemAvailable = ''
        node_filesystem_avail_bytes{job="node",fstype!~"tmpfs|devtmpfs|overlay|squashfs|ramfs|nsfs"}
        / node_filesystem_size_bytes
      '';
      scrubFresh = ''time() - node_zfs_scrub_collection_timestamp_seconds{job="node",host="fium"} < 180'';
      rules = {
        groups = [
          {
            name = "selfhosted";
            interval = "30s";
            rules = [
              {
                alert = "FilesystemSpaceLow";
                expr = "(${filesystemAvailable}) < 0.10 and node_filesystem_readonly == 0 and node_filesystem_size_bytes > 0";
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Low filesystem space on {{ $labels.instance }}";
                  description = "{{ $labels.mountpoint }} has less than 10% space available for 15 minutes.";
                };
              }
              {
                alert = "FilesystemSpaceLow";
                expr = "(${filesystemAvailable}) < 0.05 and node_filesystem_readonly == 0 and node_filesystem_size_bytes > 0";
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Low filesystem space on {{ $labels.instance }}";
                  description = "{{ $labels.mountpoint }} has less than 5% space available for 5 minutes.";
                };
              }
              {
                alert = "MemoryAvailableLow";
                expr = ''node_memory_MemAvailable_bytes{job="node"} / node_memory_MemTotal_bytes < 0.10'';
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "Low memory on {{ $labels.instance }}";
                  description = "Less than 10% memory is available for 10 minutes.";
                };
              }
              {
                alert = "MemoryAvailableLow";
                expr = ''node_memory_MemAvailable_bytes{job="node"} / node_memory_MemTotal_bytes < 0.05'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Low memory on {{ $labels.instance }}";
                  description = "Less than 5% memory is available for 5 minutes.";
                };
              }
              {
                alert = "ZfsPoolSpaceLow";
                expr = ''zfs_pool_allocated_bytes{job="zfs"} / zfs_pool_size_bytes > 0.80'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Low ZFS pool space on {{ $labels.instance }}";
                  description = "Pool {{ $labels.pool }} is more than 80% full for 15 minutes.";
                };
              }
              {
                alert = "ZfsPoolSpaceLow";
                expr = ''zfs_pool_allocated_bytes{job="zfs"} / zfs_pool_size_bytes > 0.90'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Low ZFS pool space on {{ $labels.instance }}";
                  description = "Pool {{ $labels.pool }} is more than 90% full for 5 minutes.";
                };
              }
              {
                alert = "ZfsPoolUnhealthy";
                expr = ''zfs_pool_health{job="zfs"} != 0'';
                for = "2m";
                labels.severity = "critical";
                annotations = {
                  summary = "ZFS pool fault on {{ $labels.instance }}";
                  description = "Pool {{ $labels.pool }} is not ONLINE. Check zpool status.";
                };
              }
              {
                alert = "SmartHealthFailed";
                expr = ''smartctl_device_smart_status{job="smartctl",host=~"fium|minidesk"} == 0'';
                for = "2m";
                labels.severity = "critical";
                annotations = {
                  summary = "SMART health failed on {{ $labels.host }}";
                  description = "Drive {{ $labels.device }} reports failed overall health. Check smartctl.";
                };
              }
              {
                alert = "SmartDrivesUnreported";
                expr = ''(smartctl_devices{job="smartctl",host=~"fium|minidesk"} - on(host,instance) (count by(host,instance) (smartctl_device{job="smartctl",host=~"fium|minidesk"}) or on(host,instance) (0 * smartctl_devices{job="smartctl",host=~"fium|minidesk"}))) > 0'';
                for = "10m";
                labels.severity = "critical";
                annotations = {
                  summary = "SMART data missing on {{ $labels.host }}";
                  description = "The exporter discovered more drives than it could read. Check device permissions and exporter logs.";
                };
              }
              {
                alert = "ZfsScrubMissing";
                expr = ''(node_zfs_pool_last_scrub_timestamp_seconds{job="node",host="fium"} == 0) and on(instance,host) (${scrubFresh})'';
                for = "10d";
                labels.severity = "warning";
                annotations = {
                  summary = "No completed ZFS scrub on {{ $labels.host }}";
                  description = "Pool {{ $labels.pool }} has no recorded completed scrub after 10 days.";
                };
              }
              {
                alert = "ZfsScrubOverdue";
                expr = ''(time() - (node_zfs_pool_last_scrub_timestamp_seconds{job="node",host="fium"} > 0) > 10 * 24 * 60 * 60) and on(instance,host) (${scrubFresh})'';
                for = "30m";
                labels.severity = "warning";
                annotations = {
                  summary = "ZFS scrub overdue on {{ $labels.host }}";
                  description = "Pool {{ $labels.pool }} has not completed a scrub in over 10 days.";
                };
              }
              {
                alert = "ZfsScrubCollectionStale";
                expr = ''(up{job="node",host="fium"} == 1) unless on(instance,host) (${scrubFresh})'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "ZFS scrub metrics stale on {{ $labels.host }}";
                  description = "The scrub metadata collector has not reported fresh data for 5 minutes.";
                };
              }
              {
                alert = "MonitoringExporterDown";
                expr = ''up{job=~"node|zfs",host="${config.networking.hostName}"} == 0 or up{job="smartctl",host=~"fium|minidesk"} == 0'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Exporter unavailable on {{ $labels.host }}";
                  description = "Prometheus cannot collect {{ $labels.job }} metrics from {{ $labels.instance }} for 5 minutes.";
                };
              }
              {
                alert = "ZfsCollectionFailed";
                expr = ''zfs_scrape_collector_success{job="zfs"} == 0'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "ZFS collection failed on {{ $labels.instance }}";
                  description = "The {{ $labels.collector }} collector has failed for 5 minutes. Pool values can be stale.";
                };
              }
            ];
          }
        ];
      };
    in
    {
      config = {
        services.prometheus = {
          ruleFiles = [ (pkgs.writeText "selfhosted-alert-rules.json" (builtins.toJSON rules)) ];
          alertmanagers = [
            { static_configs = [ { targets = [ "127.0.0.1:${toString alertmanager.port}" ]; } ]; }
          ];
          alertmanager = {
            enable = true;
            listenAddress = "127.0.0.1";
            openFirewall = false;
            extraFlags = [ "--cluster.listen-address=" ];
            configText = builtins.toJSON {
              route = {
                receiver = "discard";
                group_by = [
                  "alertname"
                  "host"
                  "instance"
                ];
                group_wait = "30s";
                group_interval = "5m";
                repeat_interval = "4h";
                routes = lib.optional matrixEnabled {
                  receiver = "matrix";
                  matchers = [ ''severity=~"warning|critical"'' ];
                };
              };
              inhibit_rules = [
                {
                  source_matchers = [ ''severity="critical"'' ];
                  target_matchers = [ ''severity="warning"'' ];
                  equal = [
                    "alertname"
                    "instance"
                    "device"
                    "mountpoint"
                    "pool"
                  ];
                }
              ];
              receivers = [
                { name = "discard"; }
              ]
              ++ lib.optional matrixEnabled {
                name = "matrix";
                webhook_configs = [
                  {
                    url = "http://127.0.0.1:9187/alertmanager";
                    send_resolved = true;
                  }
                ];
              };
            };
          };
        };

        sops.secrets = lib.mkIf matrixEnabled {
          matrix.restartUnits = [ "matrix-notifier.service" ];
          "matrix-chat".restartUnits = [ "matrix-notifier.service" ];
        };

        systemd.services.matrix-notifier = lib.mkIf matrixEnabled {
          description = "Deliver Alertmanager alerts and Comin deployments to Matrix";
          wantedBy = [ "multi-user.target" ];
          after = [
            "network-online.target"
            "prometheus.service"
          ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "simple";
            DynamicUser = true;
            StateDirectory = "matrix-notifier";
            LoadCredential = [
              "matrix:${config.sops.secrets.matrix.path}"
              "matrix-chat:${config.sops.secrets."matrix-chat".path}"
            ];
            ExecStart = "${lib.getExe pkgs.python3} ${./matrix-notifier.py} /run/credentials/matrix-notifier.service/matrix /run/credentials/matrix-notifier.service/matrix-chat /var/lib/matrix-notifier";
            Restart = "on-failure";
            RestartSec = "10s";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            UMask = "0077";
          };
        };
      };
    };
}

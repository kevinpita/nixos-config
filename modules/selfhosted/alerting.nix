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
      telegramEnabled = config.selfhosted.metrics.telegram.enable && !ciMode;
      alertmanager = config.services.prometheus.alertmanager;
      filesystemAvailable = ''
        node_filesystem_avail_bytes{job="node",fstype!~"tmpfs|devtmpfs|overlay|squashfs|ramfs|nsfs"}
        / node_filesystem_size_bytes
      '';
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
                alert = "MonitoringExporterDown";
                expr = ''up{job=~"node|zfs",host="${config.networking.hostName}"} == 0'';
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
      options.selfhosted.metrics.telegram.enable =
        lib.mkEnableOption "Telegram warning, critical, and recovery messages using the host's SOPS secrets";

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
            # The numeric chat ID is available only after runtime substitution.
            checkConfig = !telegramEnabled;
            environmentFile = lib.mkIf telegramEnabled config.sops.templates."alertmanager.env".path;
            configText = lib.replaceStrings [ ''"@TELEGRAM_CHAT_ID@"'' ] [ "\${TELEGRAM_CHAT_ID}" ] (
              builtins.toJSON {
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
                  routes = lib.optional telegramEnabled {
                    receiver = "telegram";
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
                ++ lib.optional telegramEnabled {
                  name = "telegram";
                  telegram_configs = [
                    {
                      bot_token_file = "/run/credentials/alertmanager.service/telegram-bot-token";
                      chat_id = "@TELEGRAM_CHAT_ID@";
                      parse_mode = "";
                      send_resolved = true;
                      message = ''
                        {{ range .Alerts }}{{ .Status | toUpper }} [{{ .Labels.severity }}] {{ .Labels.alertname }}
                        {{ .Annotations.summary }}
                        {{ .Annotations.description }}

                        {{ end }}
                      '';
                    }
                  ];
                };
              }
            );
          };
        };

        sops = lib.mkIf telegramEnabled {
          secrets = {
            telegram-bot-token.restartUnits = [ "alertmanager.service" ];
            telegram-chat-id.restartUnits = [ "alertmanager.service" ];
          };
          templates."alertmanager.env" = {
            content = ''
              TELEGRAM_CHAT_ID=${config.sops.placeholder.telegram-chat-id}
            '';
            restartUnits = [ "alertmanager.service" ];
          };
        };

        systemd.services.alertmanager.serviceConfig = {
          UMask = "0077";
          LoadCredential = lib.mkIf telegramEnabled [
            "telegram-bot-token:${config.sops.secrets.telegram-bot-token.path}"
          ];
          ExecStartPre = lib.mkAfter [
            "${alertmanager.package}/bin/amtool check-config /tmp/alert-manager-substituted.yaml"
          ];
        };
      };
    };
}

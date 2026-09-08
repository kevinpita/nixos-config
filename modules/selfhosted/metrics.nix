{ config, lib, ... }:
let
  monitoredHosts = lib.filterAttrs (
    _: host: host.config.services.prometheus.exporters.node.enable
  ) config.flake.nixosConfigurations;
  zfsHosts = lib.filterAttrs (
    _: host: host.config.services.prometheus.exporters.zfs.enable
  ) config.flake.nixosConfigurations;
in
{
  flake.modules.nixos.selfhosted =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.selfhosted.metrics;
      prometheus = config.services.prometheus;
      grafana = config.services.grafana;
    in
    {
      options.selfhosted.metrics = {
        tailnetDomain = lib.mkOption {
          type = lib.types.nonEmptyStr;
          example = "example.ts.net";
          description = "Tailscale MagicDNS suffix used by the monitored NixOS hosts.";
        };
        extraNodeTargets = lib.mkOption {
          type = lib.types.listOf lib.types.nonEmptyStr;
          default = [ ];
          example = [ "nas.example.ts.net:9100" ];
          description = "Additional node-exporter host:port endpoints reachable from this host.";
        };
      };

      config = {
        assertions = [
          {
            assertion = config.services.tailscale.enable && config.networking.firewall.enable;
            message = "selfhosted metrics requires Tailscale and the host firewall.";
          }
        ];

        services.prometheus = {
          enable = true;
          listenAddress = "127.0.0.1";
          retentionTime = "30d";
          extraFlags = [ "--storage.tsdb.retention.size=5GB" ];
          globalConfig.scrape_interval = "30s";
          scrapeConfigs = [
            {
              job_name = "node";
              static_configs =
                lib.mapAttrsToList (_: host: {
                  targets = [
                    "${host.config.networking.hostName}.${cfg.tailnetDomain}:${toString host.config.services.prometheus.exporters.node.port}"
                  ];
                  labels.host = host.config.networking.hostName;
                }) monitoredHosts
                ++ lib.optional (cfg.extraNodeTargets != [ ]) { targets = cfg.extraNodeTargets; };
            }
            {
              job_name = "zfs";
              static_configs = lib.mapAttrsToList (_: host: {
                targets = [
                  "${host.config.networking.hostName}.${cfg.tailnetDomain}:${toString host.config.services.prometheus.exporters.zfs.port}"
                ];
                labels.host = host.config.networking.hostName;
              }) zfsHosts;
            }
            {
              job_name = "prometheus";
              static_configs = [ { targets = [ "127.0.0.1:${toString prometheus.port}" ]; } ];
            }
          ];
        };

        services.grafana = {
          enable = true;
          openFirewall = false;
          settings = {
            server = {
              http_addr = "0.0.0.0";
              domain = config.networking.hostName;
            };
            security = {
              admin_password = "$__file{${grafana.dataDir}/admin-password}";
              secret_key = "$__file{${grafana.dataDir}/secret-key}";
            };
            users.allow_sign_up = false;
            "auth.anonymous".enabled = false;
            plugins.preinstall_disabled = true;
            analytics = {
              reporting_enabled = false;
              check_for_updates = false;
              check_for_plugin_updates = false;
            };
          };
          provision = {
            enable = true;
            datasources.settings.datasources = [
              {
                name = "Prometheus";
                uid = "prometheus";
                type = "prometheus";
                access = "proxy";
                url = "http://127.0.0.1:${toString prometheus.port}";
                isDefault = true;
                jsonData.timeInterval = prometheus.globalConfig.scrape_interval;
              }
            ];
          };
        };

        systemd.services.grafana.preStart = ''
          umask 077
          for file in admin-password secret-key; do
            if [ ! -s "$file" ]; then
              ${lib.getExe pkgs.openssl} rand -hex 32 > "$file.tmp"
              mv "$file.tmp" "$file"
            fi
          done
        '';

        networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts =
          lib.optionals
            (
              !(builtins.elem grafana.settings.server.http_addr [
                "127.0.0.1"
                "::1"
              ])
            )
            [
              grafana.settings.server.http_port
            ];
      };
    };
}

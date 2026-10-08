{ config, ... }:
let
  hosts = config.flake.nixosConfigurations;

  # Each job scrapes every host where its exporter is enabled.
  exporterJobs = {
    node.exporter = host: host.services.prometheus.exporters.node;
    zfs.exporter = host: host.services.prometheus.exporters.zfs;
    smartctl = {
      exporter = host: host.services.prometheus.exporters.smartctl;
      scrape_interval = "1m";
      scrape_timeout = "30s";
    };
    podman.exporter = host: host.services.podman-exporter or { enable = false; };
    ilofan.exporter = host: {
      enable = host.services.ilofan.enable or false;
      port = 9877;
    };
    comin.exporter = host: {
      enable = host.services.comin.enable or false;
      inherit (host.services.comin.exporter) port;
    };
  };
in
{
  flake.modules.nixos.selfhosted =
    {
      config,
      lib,
      pkgs,
      tailnetDomain,
      ...
    }:
    let
      prometheus = config.services.prometheus;
      grafana = config.services.grafana;
    in
    {
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
          scrapeConfigs =
            lib.mapAttrsToList (
              job: settings:
              removeAttrs settings [ "exporter" ]
              // {
                job_name = job;
                static_configs = lib.pipe hosts [
                  (lib.filterAttrs (_: host: (settings.exporter host.config).enable))
                  (lib.mapAttrsToList (
                    _: host: {
                      targets = [
                        "${host.config.networking.hostName}.${tailnetDomain}:${toString (settings.exporter host.config).port}"
                      ];
                      labels.host = host.config.networking.hostName;
                    }
                  ))
                ];
              }
            ) exporterJobs
            ++ [
              {
                job_name = "prometheus";
                static_configs = [ { targets = [ "127.0.0.1:${toString prometheus.port}" ]; } ];
              }
            ];
        };

        services.grafana = {
          enable = true;
          openFirewall = false;
          declarativePlugins = [ pkgs.grafanaPlugins.prometheus ];
          settings = {
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
      };
    };
}

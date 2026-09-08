{
  flake.modules.nixos.selfhosted-web =
    {
      config,
      lib,
      pkgs,
      ciMode,
      ...
    }:
    let
      cfg = config.selfhosted.web;
      grafanaDomain = "grafana.${cfg.domain}";
      argoDomain = "argo.${cfg.domain}";
      chartVersion = "10.8.2";
      ingressChartVersion = "41.5.0";
      hostIPv4Addresses = lib.concatMap (
        interface: map (address: address.address) interface.ipv4.addresses
      ) (lib.attrValues config.networking.interfaces);
    in
    {
      options.selfhosted.web = {
        domain = lib.mkOption {
          type = lib.types.nonEmptyStr;
          description = "Public DNS zone for the tailnet-only web services.";
        };
        tailscaleIPv4 = lib.mkOption {
          type = lib.types.nonEmptyStr;
          description = "This host's registered Tailscale IPv4 address.";
        };
      };

      config = {
        assertions = [
          {
            assertion = config.services.tailscale.enable && config.networking.firewall.enable;
            message = "selfhosted-web requires Tailscale and the host firewall.";
          }
          {
            assertion = config.services.k3s.enable && config.services.k3s.role == "server";
            message = "selfhosted-web requires a K3s server with its default CoreDNS service.";
          }
          {
            assertion = config.services.grafana.enable;
            message = "selfhosted-web requires Grafana.";
          }
          {
            assertion = builtins.elem "traefik" config.services.k3s.disable;
            message = "selfhosted-web installs private-ingress; keep the packaged K3s Traefik disabled.";
          }
        ];

        services.caddy = {
          enable = true;
          openFirewall = false;
          package = pkgs.caddy.withPlugins {
            plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
            hash = "sha256-dQvk6ezY6TQ1J7PjhCXnThF/SqVgPwBO8/RXzHCY+js=";
          };
          environmentFile =
            if ciMode then
              "/run/secrets/rendered/caddy-cloudflare.env"
            else
              config.sops.templates."caddy-cloudflare.env".path;
          globalConfig = ''
            default_bind ${cfg.tailscaleIPv4}
            auto_https disable_redirects
          '';
          virtualHosts = {
            "http://*.${cfg.domain}" = {
              logFormat = null;
              extraConfig = ''
                redir https://{host}{uri} permanent
              '';
            };
            "*.${cfg.domain}".extraConfig = ''
              tls {
                dns cloudflare {env.CLOUDFLARE_API_TOKEN}
                resolvers 1.1.1.1 1.0.0.1
              }

              @grafana host ${grafanaDomain}
              handle @grafana {
                reverse_proxy 127.0.0.1:${toString config.services.grafana.settings.server.http_port}
              }

              @argo host ${argoDomain}
              handle @argo {
                @grpc header_regexp Content-Type "^application/grpc([+;]|$)"
                reverse_proxy @grpc {
                  dynamic a argocd-server.argocd.svc.cluster.local 80 {
                    resolvers 10.43.0.10:53
                    versions ipv4
                  }
                  transport http {
                    versions h2c 2
                  }
                }
                reverse_proxy {
                  dynamic a argocd-server.argocd.svc.cluster.local 80 {
                    resolvers 10.43.0.10:53
                    versions ipv4
                  }
                  transport http {
                    versions 1.1
                  }
                }
              }

              handle {
                reverse_proxy {
                  dynamic a private-ingress.ingress.svc.cluster.local 80 {
                    resolvers 10.43.0.10:53
                    versions ipv4
                  }
                }
              }
            '';
          };
        };

        sops = lib.mkIf (!ciMode) {
          secrets.cloudflare-api-token.restartUnits = [ "caddy.service" ];
          templates."caddy-cloudflare.env" = {
            content = "CLOUDFLARE_API_TOKEN=${config.sops.placeholder.cloudflare-api-token}\n";
            restartUnits = [ "caddy.service" ];
          };
        };

        systemd.services.caddy = {
          after = [ "tailscaled.service" ];
          wants = [ "tailscaled.service" ];
          unitConfig.StartLimitIntervalSec = lib.mkForce 0;
          serviceConfig.RestartPreventExitStatus = lib.mkForce [ ];
        };

        services.grafana.settings = {
          server = {
            http_addr = lib.mkForce "127.0.0.1";
            domain = lib.mkForce grafanaDomain;
            root_url = "https://${grafanaDomain}/";
            enforce_domain = true;
          };
          security.cookie_secure = true;
        };

        services.k3s.autoDeployCharts.argocd = {
          name = "argo-cd";
          repo = "https://argoproj.github.io/argo-helm";
          version = chartVersion;
          hash = "sha256-lvtasol+PIdYzY/vQJpGZo7xoZpTgRaxErBpFhSkjyA=";
          targetNamespace = "argocd";
          createNamespace = true;
          extraFieldDefinitions.spec.version = chartVersion;
          values = {
            global.domain = argoDomain;
            configs.params."server.insecure" = true;
            server.service.type = "ClusterIP";
          };
        };

        services.k3s.autoDeployCharts.private-ingress = {
          name = "traefik";
          repo = "https://traefik.github.io/charts";
          version = ingressChartVersion;
          hash = "sha256-MPjbcxggGbJ2QXnX/Ap+/JUFZwIE+Ef/w6d5usquOho=";
          targetNamespace = "ingress";
          createNamespace = true;
          extraFieldDefinitions.spec.version = ingressChartVersion;
          values = {
            fullnameOverride = "private-ingress";
            service.spec.type = "ClusterIP";
            ingressClass = {
              name = "traefik";
              isDefaultClass = false;
            };
            providers = {
              kubernetesCRD.enabled = false;
              kubernetesIngress = {
                ingressClass = "traefik";
                publishedService.enabled = false;
                ingressEndpoint.ip = cfg.tailscaleIPv4;
              };
            };
            ports = {
              web = {
                asDefault = true;
                forwardedHeaders.trustedIPs = map (address: "${address}/32") (
                  [
                    "10.42.0.1"
                    cfg.tailscaleIPv4
                  ]
                  ++ hostIPv4Addresses
                );
              };
              websecure.expose.default = false;
            };
          };
        };

        networking.firewall.interfaces.${config.services.tailscale.interfaceName} = {
          allowedTCPPorts = [
            80
            443
          ];
          allowedUDPPorts = [ 443 ];
        };
      };
    };
}

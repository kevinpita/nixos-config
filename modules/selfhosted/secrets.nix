{ config, ... }:
let
  inherit (config.flake.modules.nixos) selfhosted-web;
in
{
  flake.modules.nixos.selfhosted-secrets =
    {
      config,
      lib,
      ciMode,
      ...
    }:
    let
      domain = "bao.${config.selfhosted.web.domain}";
      chartVersion = "2.10.0";
      tokenLogFilter = ''
        format filter {
          wrap json
          fields {
            request>headers>X-Vault-Token delete
            request>headers>X-Bao-Token delete
          }
        }
      '';
    in
    {
      imports = [ selfhosted-web ];

      services.openbao = {
        enable = true;
        settings = {
          ui = true;
          api_addr = "https://${domain}";
          cluster_addr = "https://127.0.0.1:8201";
          seal.static = {
            current_key_id = "1";
            current_key = "file:///run/credentials/openbao.service/seal-key";
          };
          storage.raft = {
            path = "/var/lib/openbao";
            node_id = config.networking.hostName;
          };
          listener.default = {
            type = "tcp";
            address = "127.0.0.1:8200";
            cluster_address = "127.0.0.1:8201";
            tls_disable = true;
          };
        };
      };

      sops.secrets = lib.mkIf (!ciMode) {
        openbao-auto-unseal-key.restartUnits = [ "openbao.service" ];
      };

      systemd.services.openbao = {
        restartIfChanged = lib.mkForce true;
        serviceConfig.LoadCredential = [
          "seal-key:${
            if ciMode then
              "/run/secrets/openbao-auto-unseal-key"
            else
              config.sops.secrets.openbao-auto-unseal-key.path
          }"
        ];
      };

      services.caddy = {
        logFormat = ''
          level ERROR
          ${tokenLogFilter}
        '';
        virtualHosts."*.${config.selfhosted.web.domain}" = {
          logFormat = ''
            output file ${config.services.caddy.logDir}/access-*.${config.selfhosted.web.domain}.log
            ${tokenLogFilter}
          '';
          extraConfig = lib.mkBefore ''
            @openbao host ${domain}
            handle @openbao {
              reverse_proxy 127.0.0.1:8200
            }
          '';
        };
      };

      services.k3s.autoDeployCharts.external-secrets = {
        name = "external-secrets";
        repo = "https://charts.external-secrets.io";
        version = chartVersion;
        hash = "sha256-uW6Uj/82dGOLXT+eQ4hvN5bgRznEtBJ5Ka7S3ax9FBg=";
        targetNamespace = "external-secrets";
        createNamespace = true;
        extraFieldDefinitions.spec.version = chartVersion;
        values.installCRDs = true;
      };
    };
}

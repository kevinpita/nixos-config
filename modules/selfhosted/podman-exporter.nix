{
  flake.modules.nixos.podman =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      cfg = config.services.podman-exporter;
      exporter = pkgs.callPackage ../../packages/prometheus-podman-exporter/package.nix { };
      startExporter = pkgs.writeShellApplication {
        name = "start-podman-exporter";
        runtimeInputs = [
          pkgs.iproute2
          pkgs.jq
        ];
        text = ''
          addresses=$(ip -json address show dev ${lib.escapeShellArg config.services.tailscale.interfaceName} | jq -er '
            .[].addr_info[]
            | select(.scope == "global" and (.family == "inet" or .family == "inet6"))
            | if .family == "inet6" then "[\(.local)]" else .local end
          ')
          listeners=()
          while IFS= read -r address; do
            listeners+=("--web.listen-address=$address:${toString cfg.port}")
          done <<< "$addresses"
          exec ${lib.getExe exporter} --collector.enhance-metrics "''${listeners[@]}"
        '';
      };
    in
    {
      options.services.podman-exporter = {
        enable = lib.mkEnableOption "rootless Podman metrics on the Tailscale interface" // {
          default = config.virtualisation.podman.enable;
          defaultText = lib.literalExpression "config.virtualisation.podman.enable";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 9882;
          description = "TCP port for Podman metrics on the Tailscale interface.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.virtualisation.podman.enable;
            message = "podman-exporter requires Podman.";
          }
          {
            assertion =
              config.services.tailscale.enable
              && config.services.tailscale.interfaceName != "userspace-networking"
              && config.networking.firewall.enable;
            message = "podman-exporter requires a Tailscale network interface and the host firewall.";
          }
        ];

        systemd.user.services.podman-exporter = {
          description = "Rootless Podman metrics on Tailscale";
          wantedBy = [ "default.target" ];
          requires = [ "podman.socket" ];
          after = [ "podman.socket" ];
          unitConfig = {
            ConditionUser = username;
            StartLimitIntervalSec = 0;
          };
          environment.CONTAINER_HOST = "unix://%t/podman/podman.sock";
          serviceConfig = {
            ExecStart = lib.getExe startExporter;
            Restart = "always";
            RestartSec = "15s";
            UMask = "0077";
          };
        };

        networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
          cfg.port
        ];
      };
    };
}

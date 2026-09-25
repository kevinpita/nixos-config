{ config, lib, ... }:
let
  port = 5000;
  tailnetDomain = "tail235c8.ts.net";
  hosts = config.flake.nixosConfigurations;
  # Hosts that serve their store, and workstations that switch from it.
  cacheHosts = lib.filter (host: host.config.services.harmonia.cache.enable) (lib.attrValues hosts);
  prebuildHosts = lib.attrNames (
    lib.filterAttrs (_: host: host.config.nixCache.prebuild or false) hosts
  );
in
{
  flake.modules.nixos.nix-cache-server =
    {
      config,
      lib,
      pkgs,
      ciMode,
      ...
    }:
    let
      stateDirectory = "/var/lib/nix-cache-prebuild";
    in
    {
      options.nixCache.publicKey = lib.mkOption {
        type = lib.types.nonEmptyStr;
        example = "cache-1:AAAA…=";
        description = "Public half of this host's cache signing key, trusted by workstations.";
      };

      config = {
        services.harmonia = {
          cache = {
            enable = true;
            settings.bind = "[::]:${toString port}";
            signKeyPaths = [
              (
                if ciMode then
                  "/run/secrets/nix-cache-signing-key"
                else
                  config.sops.secrets.nix-cache-signing-key.path
              )
            ];
          };
        };

        sops.secrets = lib.mkIf (!ciMode) {
          nix-cache-signing-key.restartUnits = [ "harmonia.service" ];
        };

        networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
          port
        ];

        # Keep prebuilds from starving the hosted services.
        nix = {
          daemonCPUSchedPolicy = "batch";
          daemonIOSchedClass = "idle";
        };

        # Build each workstation from the newest main commit. The out-links are
        # GC roots, so harmonia keeps serving the latest closures.
        systemd.services.nix-cache-prebuild = {
          description = "Prebuild workstation systems for the Nix cache";
          after = [
            "network-online.target"
            "sops-nix.service"
          ];
          wants = [ "network-online.target" ];
          environment.HOME = "/root";
          # Reuse Comin's GitHub identity for the private flake inputs.
          environment.GIT_SSH_COMMAND = config.systemd.services.comin.environment.GIT_SSH_COMMAND;
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "nix-cache-prebuild";
            ExecStart = lib.getExe (
              pkgs.writeShellApplication {
                name = "nix-cache-prebuild";
                runtimeInputs = [
                  config.nix.package
                  pkgs.coreutils
                  pkgs.git
                  pkgs.openssh
                ];
                text = ''
                  repository=https://github.com/kevinpita/nixos-config.git
                  revision=$(git ls-remote "$repository" refs/heads/main | cut -f1)
                  [[ -n "$revision" ]] || { echo "Could not resolve main" >&2; exit 1; }
                  if [[ "$(cat ${stateDirectory}/revision 2>/dev/null || true)" == "$revision" ]]; then
                    exit 0
                  fi

                  failed=0
                  for host in ${lib.escapeShellArgs prebuildHosts}; do
                    echo "Building $host at $revision"
                    nix build --no-write-lock-file \
                      --out-link "${stateDirectory}/$host" \
                      "git+$repository?rev=$revision#nixosConfigurations.$host.config.system.build.toplevel" \
                      || failed=1
                  done

                  echo "$revision" > ${stateDirectory}/revision
                  exit "$failed"
                '';
              }
            );
          };
        };

        systemd.timers.nix-cache-prebuild = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5min";
            OnUnitInactiveSec = "10min";
          };
        };
      };
    };

  flake.modules.nixos.workstation =
    { lib, ... }:
    {
      options.nixCache.prebuild = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether cache hosts prebuild this host's system.";
      };

      config.nix.settings = {
        extra-substituters = map (
          host: "http://${host.config.networking.hostName}.${tailnetDomain}:${toString port}"
        ) cacheHosts;
        extra-trusted-public-keys = map (host: host.config.nixCache.publicKey) cacheHosts;
        connect-timeout = 5;
        fallback = true;
      };
    };
}

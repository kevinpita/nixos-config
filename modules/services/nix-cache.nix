let
  cacheHost = "fium";
  cacheUrl = "http://${cacheHost}.tail235c8.ts.net:5000";
  cachePublicKey = "fium-cache-1:Aeu01Pv7XdRgBN33KuV5B/DXzeAwpo5nLwd3Kh79fVc=";
  # Workstations that switch from the cache instead of building locally.
  prebuildHosts = [
    "amdep"
    "t14g6"
  ];
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
      services.harmonia = {
        cache = {
          enable = true;
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
        5000
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

                # Record the revision even on failure, so a broken commit is not
                # rebuilt on every timer tick. The next commit retries.
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

  flake.modules.nixos.workstation =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      metricsDirectory = "/var/lib/nix-cache-metrics";
    in
    {
      nix.settings = {
        extra-substituters = [ cacheUrl ];
        extra-trusted-public-keys = [ cachePublicKey ];
        # Fall back to other caches or local builds when the cache host is unreachable.
        connect-timeout = 5;
        fallback = true;
      };

      services.prometheus.exporters.node.extraFlags = [
        "--collector.textfile.directory=${metricsDirectory}"
      ];

      # Substituted paths keep the signatures of the cache they came from. A path
      # signed only by the cache host was built there instead of locally. The
      # ledger keeps the total monotonic when garbage collection removes paths.
      systemd.services.nix-cache-metrics = {
        description = "Export build output received from the Nix cache host";
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = "nix-cache-metrics";
          ExecStart = lib.getExe (
            pkgs.writeShellApplication {
              name = "nix-cache-metrics";
              runtimeInputs = [
                config.nix.package
                pkgs.coreutils
                pkgs.jq
              ];
              text = ''
                ledger=${metricsDirectory}/ledger.json
                [[ -s "$ledger" ]] || echo '{}' > "$ledger"
                temporary_ledger=$(mktemp "${metricsDirectory}/.ledger.XXXXXX")
                temporary_metrics=$(mktemp "${metricsDirectory}/.metrics.XXXXXX")
                trap 'rm -f "$temporary_ledger" "$temporary_metrics"' EXIT

                nix path-info --all --json --sigs \
                  | jq --slurpfile ledger "$ledger" --arg key ${lib.escapeShellArg (lib.head (lib.splitString ":" cachePublicKey))} '
                      $ledger[0] + (
                        with_entries(
                          select(
                            (.value.signatures // []) as $signatures
                            | ($signatures | length) > 0
                            and ($signatures | all(startswith($key + ":")))
                          )
                          | .value = .value.narSize
                        )
                      )' > "$temporary_ledger"
                mv -f "$temporary_ledger" "$ledger"

                jq -r '
                  "# HELP nix_cache_saved_bytes_total Unpacked size of store paths received from the cache host that it built.",
                  "# TYPE nix_cache_saved_bytes_total counter",
                  "nix_cache_saved_bytes_total \([.[]] | add // 0)",
                  "# HELP nix_cache_saved_paths_total Store paths received from the cache host that it built.",
                  "# TYPE nix_cache_saved_paths_total counter",
                  "nix_cache_saved_paths_total \(length)"
                ' "$ledger" > "$temporary_metrics"
                chmod 0644 "$temporary_metrics"
                mv -f "$temporary_metrics" ${metricsDirectory}/nix-cache.prom
              '';
            }
          );
        };
      };

      systemd.timers.nix-cache-metrics = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "1h";
        };
      };
    };
}

{ config, lib, ... }:
let
  port = 5000;
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
      username,
      ...
    }:
    let
      stateDirectory = "/var/lib/nix-cache-prebuild";
      repository = "https://github.com/kevinpita/nixos-config.git";
      serviceDefaults = {
        after = [
          "network-online.target"
          "sops-nix.service"
        ];
        wants = [ "network-online.target" ];
        environment = {
          HOME = "/root";
          # Reuse Comin's GitHub identity for the private flake inputs.
          inherit (config.systemd.services.comin.environment) GIT_SSH_COMMAND;
        };
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = "nix-cache-prebuild";
        };
      };
      script =
        name: text:
        lib.getExe (
          pkgs.writeShellApplication {
            inherit name text;
            runtimeInputs = [
              config.nix.package
              pkgs.coreutils
              pkgs.git
              pkgs.openssh
              pkgs.util-linux
            ];
          }
        );
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

        services.prometheus.exporters.node.extraFlags = [
          "--collector.textfile.directory=${stateDirectory}"
        ];

        # Build each workstation from the newest main commit. The out-links are
        # GC roots, so harmonia keeps serving the latest closures.
        systemd.services.nix-cache-prebuild = lib.recursiveUpdate serviceDefaults {
          description = "Prebuild workstation systems for the Nix cache";
          serviceConfig.ExecStart = script "nix-cache-prebuild" ''
            revision=$(git ls-remote ${repository} refs/heads/main | cut -f1)
            [[ -n "$revision" ]] || { echo "Could not resolve main" >&2; exit 1; }
            # Publish main, so Grafana can compare the revision of each host with it.
            {
              printf '# HELP nix_cache_main_revision_info Newest commit of main that the cache host resolved.\n'
              printf '# TYPE nix_cache_main_revision_info gauge\n'
              printf 'nix_cache_main_revision_info{revision="%s"} 1\n' "$revision"
            } > ${stateDirectory}/.main.prom.tmp
            mv -f ${stateDirectory}/.main.prom.tmp ${stateDirectory}/main.prom
            if [[ "$(cat ${stateDirectory}/revision 2>/dev/null || true)" == "$revision" ]]; then
              exit 0
            fi

            failed=0
            for host in ${lib.escapeShellArgs prebuildHosts}; do
              echo "Building $host at $revision"
              nix build --no-write-lock-file \
                --out-link "${stateDirectory}/$host" \
                "git+${repository}?rev=$revision#nixosConfigurations.$host.config.system.build.toplevel" \
                || failed=1
            done

            # A failed revision stays unrecorded, so the next run retries it.
            if (( failed )); then
              exit 1
            fi
            echo "$revision" > ${stateDirectory}/revision
          '';
        };

        # Update flake inputs on top of main, build every workstation with
        # the result, and push the update to main only when all builds pass.
        # The arguments name the inputs to update, and none means all of
        # them. Workstations then pull a lock whose closures are cached.
        # Comin also deploys this commit to the servers. The checkout always
        # follows the remote main, including force pushes. The update also
        # moves omp to its newest release, which changes flake.nix and
        # omp/natives.json.
        systemd.services.nix-cache-update = lib.recursiveUpdate serviceDefaults {
          description = "Prebuild workstation systems with updated flake inputs";
          serviceConfig.ExecStart = script "nix-cache-update" ''
            # The daily and the 10-minute update share the checkout, so one
            # waits for the other.
            exec 9>${stateDirectory}/update.lock
            flock 9
            checkout=${stateDirectory}/update-checkout
            if [[ ! -d "$checkout/.git" ]]; then
              git clone --quiet ${repository} "$checkout"
            fi
            cd "$checkout"
            sync_main() {
              git fetch --quiet origin main
              git reset --quiet --hard origin/main
              git clean --quiet -fd
            }
            files=(flake.lock flake.nix omp/natives.json)
            # Comin deploys only commits signed by an allowed key.
            commit_lock() {
              git -c user.name="Kevin Pita" -c user.email=gitkevin@pm.me \
                -c gpg.format=ssh -c user.signingkey=/home/${username}/.ssh/id_ed25519_sign \
                commit --quiet --gpg-sign --message "chore: update flake.lock" -- "''${files[@]}"
            }

            sync_main
            base=$(git rev-parse HEAD)
            ${lib.getExe pkgs.omp-pin-release}
            nix flake update "$@" --flake "git+file://$checkout"
            if git diff --quiet -- "''${files[@]}"; then
              echo "Inputs are already current"
              exit 0
            fi
            commit_lock
            updated=$(git rev-parse HEAD)

            for host in ${lib.escapeShellArgs prebuildHosts}; do
              echo "Building $host with updated inputs"
              nix build --no-write-lock-file \
                --out-link "${stateDirectory}/update-$host" \
                "git+file://$checkout#nixosConfigurations.$host.config.system.build.toplevel"
            done

            # If main moved during the builds, put the built update on the new
            # main. If the new main changed one of the updated files, keep
            # that change and discard this update.
            for _ in 1 2 3; do
              git fetch --quiet origin main
              if ! git diff --quiet "$base" origin/main -- "''${files[@]}"; then
                echo "main changed ''${files[*]} during the builds, discarding this update"
                sync_main
                exit 0
              fi
              if [[ "$(git rev-parse origin/main)" != "$base" ]]; then
                sync_main
                base=$(git rev-parse HEAD)
                git checkout --quiet "$updated" -- "''${files[@]}"
                commit_lock
              fi
              if git push --quiet git@github.com:kevinpita/nixos-config.git HEAD:refs/heads/main; then
                exit 0
              fi
            done
            echo "Could not push the updated lock" >&2
            exit 1
          '';
        };

        # omp and herdr release often, so their inputs get the same update
        # every 10 minutes. A run with no new release changes nothing.
        systemd.services.nix-cache-update-fast = lib.recursiveUpdate serviceDefaults {
          description = "Prebuild workstation systems with new omp and herdr releases";
          serviceConfig.ExecStart = "${config.systemd.services.nix-cache-update.serviceConfig.ExecStart} oh-my-pi herdr-nix herdr-lazygit";
        };

        systemd.timers.nix-cache-prebuild = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5min";
            OnUnitInactiveSec = "10min";
          };
        };

        systemd.timers.nix-cache-update = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "1h";
          };
        };

        systemd.timers.nix-cache-update-fast = {
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
    };

  # Every host downloads from the cache hosts. A cache host skips itself.
  flake.modules.nixos.base =
    {
      config,
      lib,
      tailnetDomain,
      ...
    }:
    let
      otherCacheHosts = lib.filter (
        host: host.config.networking.hostName != config.networking.hostName
      ) cacheHosts;
    in
    {
      nix.settings = {
        extra-substituters = map (
          host: "http://${host.config.networking.hostName}.${tailnetDomain}:${toString port}"
        ) otherCacheHosts;
        extra-trusted-public-keys = map (host: host.config.nixCache.publicKey) otherCacheHosts;
        connect-timeout = 5;
        fallback = true;
      };
    };
}

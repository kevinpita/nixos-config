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

        # Keep prebuilds from starving the hosted services.
        nix = {
          daemonCPUSchedPolicy = "batch";
          daemonIOSchedClass = "idle";
        };

        # Build each workstation from the newest main commit. The out-links are
        # GC roots, so harmonia keeps serving the latest closures.
        systemd.services.nix-cache-prebuild = lib.recursiveUpdate serviceDefaults {
          description = "Prebuild workstation systems for the Nix cache";
          serviceConfig.ExecStart = script "nix-cache-prebuild" ''
            revision=$(git ls-remote ${repository} refs/heads/main | cut -f1)
            [[ -n "$revision" ]] || { echo "Could not resolve main" >&2; exit 1; }
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

        # Update every flake input on top of main, build every workstation
        # with the result, and push the lock to main only when all builds
        # pass. Workstations then pull a lock whose closures are cached.
        # Comin also deploys this commit to the servers. The checkout always
        # follows the remote main, including force pushes.
        systemd.services.nix-cache-update = lib.recursiveUpdate serviceDefaults {
          description = "Prebuild workstation systems with updated flake inputs";
          serviceConfig.ExecStart = script "nix-cache-update" ''
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
            # Comin deploys only commits signed by an allowed key.
            commit_lock() {
              git -c user.name=nix-cache-update -c user.email=gitkevin@pm.me \
                -c gpg.format=ssh -c user.signingkey=/home/${username}/.ssh/id_ed25519_sign \
                commit --quiet --gpg-sign --message "chore: update flake.lock" -- flake.lock
            }

            sync_main
            base=$(git rev-parse HEAD)
            nix flake update --flake "git+file://$checkout"
            if git diff --quiet -- flake.lock; then
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

            # If main moved during the builds, put the built lock on the new
            # main. If the new main has its own lock change, keep that one.
            for _ in 1 2 3; do
              git fetch --quiet origin main
              if ! git diff --quiet "$base" origin/main -- flake.lock; then
                echo "main changed flake.lock during the builds, discarding this update"
                sync_main
                exit 0
              fi
              if [[ "$(git rev-parse origin/main)" != "$base" ]]; then
                sync_main
                base=$(git rev-parse HEAD)
                git checkout --quiet "$updated" -- flake.lock
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
      };
    };

  flake.modules.nixos.workstation =
    { lib, tailnetDomain, ... }:
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

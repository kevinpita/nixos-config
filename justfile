set shell := ["bash", "-euo", "pipefail", "-c"]

root := justfile_directory()

# Check locked inputs, including the real private configuration.
check:
  nix flake check --all-systems --no-write-lock-file "{{root}}"

# Reproduce public CI without private inputs.
check-public:
  nix flake check --all-systems --no-write-lock-file --override-input nixos-secrets "path:{{root}}/ci-dummy-input" --override-input nixos-work "path:{{root}}/ci-dummy-input" "{{root}}"

# Check development changes in the local Pi and Hyprland repositories.
check-local:
  nix flake check --all-systems --no-write-lock-file --override-input nixos-pi "path:$HOME/nixos-pi" --override-input nixos-hyprland "path:$HOME/nixos-hyprland" "{{root}}"

# Build this host with locked inputs. Do not activate it.
build:
  nh os build --no-write-lock-file "{{root}}"

# Build this host with local Pi and Hyprland development changes.
build-local:
  nh os build --no-write-lock-file --override-input nixos-pi "path:$HOME/nixos-pi" --override-input nixos-hyprland "path:$HOME/nixos-hyprland" "{{root}}"

# Run a rootless container with isolated storage. Do not use the current image store.
test-podman:
  #!/usr/bin/env bash
  set -euo pipefail
  host="$(hostname)"
  podman="$(nix build --no-link --print-out-paths --no-write-lock-file "{{root}}#nixosConfigurations.$host.config.virtualisation.podman.package^out")"
  policy="$(nix build --no-link --print-out-paths --no-write-lock-file "{{root}}#nixosConfigurations.$host.pkgs.skopeo.policy")"
  image="$(nix build --no-link --print-out-paths --no-write-lock-file "{{root}}#podman-test-image")"
  bash "{{root}}/tests/podman-smoke.sh" "$podman/bin/podman" "$image" "$policy/default-policy.json"

# Check the real locked configuration before applying it.
switch: check
  nh os switch --no-write-lock-file "{{root}}"

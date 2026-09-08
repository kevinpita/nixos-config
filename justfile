set shell := ["bash", "-euo", "pipefail", "-c"]

root := justfile_directory()

# Check locked inputs, including the real private configuration.
check:
  nix flake check --all-systems --no-write-lock-file "{{root}}"

# Reproduce public CI without private inputs.
check-public:
  nix flake check --all-systems --no-write-lock-file --override-input nixos-secrets "path:{{root}}/ci-dummy-input" --override-input nixos-work "path:{{root}}/ci-dummy-input" "{{root}}"

# Check development changes in the local Pi extension repository.
check-local:
  nix flake check --all-systems --no-write-lock-file --override-input pi-extensions "path:$HOME/nixos-pi" "{{root}}"

# Build this host with locked inputs. Do not activate it.
build:
  nh os build --no-write-lock-file "{{root}}"

# Build this host with local Pi extension changes.
build-local:
  nh os build --no-write-lock-file --override-input pi-extensions "path:$HOME/nixos-pi" "{{root}}"

# Check the real locked configuration before applying it.
switch: check
  nh os switch --no-write-lock-file "{{root}}"

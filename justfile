set shell := ["bash", "-euo", "pipefail", "-c"]

root := justfile_directory()

# Check every system with the local Pi and Hyprland checkouts.
check:
  nix flake check --all-systems --no-write-lock-file --override-input nixos-pi "path:$HOME/nixos-pi" --override-input nixos-hyprland "path:$HOME/nixos-hyprland" "{{root}}"

# Build this host with the local Pi and Hyprland checkouts.
build:
  nh os build --no-write-lock-file --override-input nixos-pi "path:$HOME/nixos-pi" --override-input nixos-hyprland "path:$HOME/nixos-hyprland" "{{root}}"

# Apply this host with the locked flake inputs.
switch:
  nh os switch --no-write-lock-file "{{root}}"

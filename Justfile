set shell := ["bash", "-euo", "pipefail", "-c"]

# List the available project commands.
default:
    @just --list

# Refuse to touch a disk that is open by the Hyprland VM.
_ensure-vm-stopped:
    @if pgrep -f '[q]emu-(system[^ ]*|kvm).* -name hyprland-vm' >/dev/null; then \
        echo "hyprland-vm is already running; exit it with Super+Shift+E first" >&2; \
        exit 1; \
    fi

# Build the latest configuration and open the persistent KVM/VirGL VM.
vm: _ensure-vm-stopped
    nix run 'path:.#hyprland-vm'

# Delete all guest state, rebuild, and open a fresh KVM/VirGL VM.
vm-reset: _ensure-vm-stopped
    @state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-vm"; \
        echo "Removing $state_dir/hyprland-vm.qcow2"; \
        rm -f "$state_dir/hyprland-vm.qcow2"
    nix run 'path:.#hyprland-vm'

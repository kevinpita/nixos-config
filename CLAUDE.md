# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

```bash
# Apply configuration changes (uses nh)
nh os switch ~/nixos-config

# Update flake.lock dependencies
nix flake update

# Check formatting and linting
nix flake check

# Format all files
nix fmt

# Deploy to a new machine via nixos-anywhere
nix run github:nix-community/nixos-anywhere -- --flake ~/nixos-config#<hostname> root@<ip>
```

## Architecture Overview

Flakes-based NixOS configuration managing 5 hosts (2 laptops, 1 workstation, 2 servers) with a three-tier module system: core (always applied), features (opt-in per host), and host-specific overrides.

### Module Composition Flow

`nixos-configurations.nix` is the orchestration center. The `mkHost` factory builds each host by composing:

1. `hosts/<hostname>/` — hardware config, disko partitioning, host-specific overrides
1. `modules/core/` — always-on system config (boot, networking, users, shell, programs, nix-settings, secrets)
1. `modules/features/` — conditionally enabled via `features.<name>.enable`
1. Flake input modules (home-manager, disko, sops-nix, comin)

`specialArgs` passes `inputs`, `username` ("kevin", hardcoded), and `hostname` to all modules. Home Manager is integrated directly into system config via `modules/core/users.nix`, which also forwards `features` config down via `extraSpecialArgs`.

### Key Configuration Patterns

**Feature flags**: Hosts enable functionality via `features.<name>.enable = true` in their `default.nix`. Options defined in `modules/features/default.nix`, each feature module wraps its config in `lib.mkIf config.features.<name>.enable`.

**Custom options**: Some core modules define options (e.g., `bootloader.mode` bios/uefi) using `lib.mkOption` with `lib.mkIf` for conditional logic.

**Host structure**: Each host's `default.nix` imports hardware-configuration.nix, disko-config.nix, and optional host-specific files (custom networking, drive monitoring, syncthing overrides), then enables desired features.

### Secrets Architecture

Secrets are managed via sops-nix with age encryption. The secrets live in a separate private repo (`nixos-secrets`) pulled as a non-flake input. `modules/core/secrets.nix` configures:

- Per-host secrets from `secrets/<hostname>.yaml`
- Shared secrets from `secrets/common.yaml` (user password)
- SSH auth and signing keys deployed to `~/.ssh/`
- Age key at `/var/lib/sops-nix/key.txt` (shipped during deploy via `--extra-files`)

The secrets input is optional — `inputs ? nixos-secrets` check allows the config to compile without it.

### Hosts

| Host | Type | GUI | Features |
|------|------|-----|----------|
| t480, t480s | ThinkPad laptops | GNOME | desktop, development, virtualization, browsers, multimedia, communication, syncthing, printing-3d |
| amdep | Workstation | GNOME | desktop, development, virtualization, browsers, multimedia, communication, syncthing |
| m710q | Server | No | ssh-server, syncthing |
| microg8 | Server | No | ssh-server, syncthing, auto-update (comin) |

## Code Style

- Formatting enforced by treefmt (nixfmt, deadnix, statix, yamlfmt, mdformat)
- CI runs `nix flake check --all-systems` on all branches/PRs

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

This is a flakes-based NixOS configuration managing multiple hosts with a modular design separating system (NixOS) and user (Home Manager) configurations.

### Directory Structure

- **flake.nix** - Entry point defining all hosts and inputs
- **hosts/** - Machine-specific configurations (each contains `default.nix`, `hardware-configuration.nix`, `disko-config.nix`)
- **modules/core/** - System-level modules always applied (boot, networking, nix-settings, users, shell, programs)
- **modules/features/** - Opt-in feature modules enabled per-host via `features.<name>.enable`

### Hosts

| Host | Type | GUI | Notes |
|------|------|-----|-------|
| t480, t480s | ThinkPad laptops | Yes | GNOME desktop |
| amdep | Laptop | Yes | GNOME desktop |
| m710q | Server | No | Headless |
| microg8 | Server | No | Runs comin for config sync |

### Key Configuration Patterns

**Feature flags**: Hosts enable functionality via `features.<name>.enable = true`. Available features: desktop, development, virtualization, browsers, multimedia, communication, syncthing, ssh-server, printing-3d, laptop, auto-update.

**Special args flow**: `hostname`, `username` ("kevin"), and `inputs` are passed through `specialArgs` to all modules.

**Host structure**: Each host's `default.nix` imports hardware config, disko config, and optional host-specific overrides, then enables desired features.

**Custom options**: Modules define options like `bootloader.mode` (bios/uefi) using `lib.mkOption`, then use `lib.mkIf` for conditional logic.

### Key Flake Inputs

- **nixpkgs** (nixos-unstable) - Package repository
- **home-manager** - User environment management
- **disko** - Declarative disk partitioning
- **nixos-hardware** - Hardware-specific configurations
- **sops-nix** - Secrets management
- **comin** - Automatic configuration deployment

## Code Style

- Formatting enforced by treefmt (nixfmt, deadnix, statix, yamlfmt, mdformat)
- CI runs `nix flake check --all-systems` on all branches/PRs

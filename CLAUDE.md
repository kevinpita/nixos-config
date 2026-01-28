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
- **modules/nixos/** - System-level modules (bootloader, networking, docker, gnome, etc.)
- **modules/home/** - User-level modules (git, zsh, vscode, development tools, etc.)

### Hosts

| Host | Type | GUI | Notes |
|------|------|-----|-------|
| t480, t480s | ThinkPad laptops | Yes | GNOME desktop |
| amdep | Laptop | Yes | GNOME desktop |
| m710q | Server | No | Headless |
| microg8 | Server | No | Runs comin for config sync |

### Key Configuration Patterns

**Conditional GUI loading**: The `gui.enable` option (set per-host) controls whether desktop modules load. SSH server only enables on non-GUI systems.

**Special args flow**: `hostname`, `username` ("kevin"), and `inputs` are passed through `specialArgs` to all modules.

**Module imports**: Host `default.nix` imports hardware config → disko → nixos modules → home-manager → host-specific overrides.

**Custom options**: Modules define options like `bootloader.mode` (bios/uefi) using `lib.mkOption`, then use `lib.mkIf` for conditional logic.

### Key Flake Inputs

- **nixpkgs** (nixos-unstable) - Package repository
- **home-manager** - User environment management
- **disko** - Declarative disk partitioning
- **nixos-hardware** - Hardware-specific configurations
- **sops-nix** - Secrets management

## Code Style

- Formatting enforced by treefmt (nixfmt, deadnix, statix, yamlfmt, mdformat)
- CI runs `nix flake check --all-systems` on all branches/PRs

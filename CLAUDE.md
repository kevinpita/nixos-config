# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

```bash
# Apply configuration changes (uses nh, configured to point at ~/nixos-config)
nh os switch ~/nixos-config

# Update flake.lock dependencies
nix flake update

# Update a single input
nix flake update <input-name>

# Check formatting and evaluate all hosts (matches CI)
nix flake check --all-systems

# Format all files via treefmt (nixfmt, deadnix, statix, yamlfmt, mdformat)
nix fmt

# Deploy to a new machine
nix run github:nix-community/nixos-anywhere -- --flake ~/nixos-config#<hostname> root@<ip>
```

See `README.md` for the full deploy/reinstall flow with sops age keys and `--extra-files`.

## Architecture

Flakes-based NixOS configuration for 5 hosts using a three-tier module system: **core** (always applied), **features** (opt-in per host), and **host-specific overrides**.

### Module Composition

`nixos-configurations.nix` is the orchestration center. The `mkHost` factory builds each host by composing:

1. `hosts/<hostname>/` (hardware, disko, host overrides)
1. `modules/core/` (always-on: boot, networking, users, programs, nix-settings, secrets, zsh)
1. `modules/features/` (conditionally enabled via `features.<name>.enable`)
1. Flake input modules (home-manager, disko, sops-nix, comin, nvim-config)

`specialArgs` passes `inputs`, `username` ("kevin", hardcoded in `nixos-configurations.nix`), and `hostname` to every module. Home Manager is integrated into system config via `modules/core/users.nix`, which forwards `config.features` down to HM through `extraSpecialArgs`. So feature flags are visible from both NixOS and Home Manager modules.

`pkgs` is constructed once in `nixos-configurations.nix` with the overlay set (vscode extensions, claude-code, codex, gemini, helm-tui pin, herdr) and `allowUnfree = true`, then shared across all hosts.

### Feature flag pattern

Options are declared in `modules/features/default.nix` with `lib.mkEnableOption`, organized into subdirs (`cloud/`, `dev/`, `ui/`, `net/`, `system/`, `misc/`). Each feature file wraps its config in `lib.mkIf config.features.<name>.enable`. Hosts opt in by setting `features.<name>.enable = true` in their `default.nix`.

When adding a new feature: declare the option in `modules/features/default.nix`, add the import there, and gate the entire module body with `lib.mkIf`.

### Custom options

Some core modules expose typed options instead of feature flags (`modules/core/boot.nix` defines `bootloader.mode` enum bios/uefi, `kernelPackages`, `uefiOSProber`). Hosts override these directly in their `default.nix` (e.g., `bootloader.mode = "bios"` on microg8, `uefiOSProber = true` on dual-boot hosts).

### Hosts

| Host | Type | Notes |
| ------- | ------------------- | ------------------------------------------- |
| amdep | Workstation | Full desktop, dual-boot |
| hulk | Server | k3s single-node, kubernetes tools |
| microg8 | Server | BIOS boot, comin auto-update, drive monitor |
| t14g6 | Laptop | Full desktop, TLP |
| t480s | ThinkPad laptop | Full desktop, TLP, dual-boot, nixos-hardware module |

### Secrets (sops-nix + age)

Secrets live in a separate private repo (`nixos-secrets`) pulled as a non-flake input. `modules/core/secrets.nix`:

- Per-host secrets from `secrets/<hostname>.yaml`
- Shared `user-password` from `secrets/common.yaml`
- SSH auth + signing keys deployed to `~/.ssh/`
- Age key at `/var/lib/sops-nix/key.txt` (shipped via `nixos-anywhere --extra-files` on first deploy)

The `inputs ? nixos-secrets` guard lets the config evaluate without the private repo. CI exploits this by passing a dummy `--override-input nixos-secrets path:./ci-dummy-input` (and same for `nixos-work`). Keep new sops integrations behind the same guard.

The `work.nix` feature follows the same pattern: it imports `nixos-work` as a non-flake input and applies its returned config only when both the input is present and `features.work.enable` is set.

## Conventions

- Conventional commits, no commit body/description.
- No em dashes anywhere (use commas/parentheses), no `→` (use `->`).
- treefmt enforces format on CI (`nix flake check --all-systems` runs on every push/PR via `.github/workflows/nix-config-check.yml`).

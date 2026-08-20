# AGENTS.md / CLAUDE.md

This file provides agent guidance for this repository. `AGENTS.md` is a symlink to this file, so edit `CLAUDE.md` as the source of truth.

## Build and Development Commands

```bash
# Apply configuration changes (uses nh, configured to point at ~/nixos-config)
nh os switch ~/nixos-config

# Update flake.lock dependencies
nix flake update

# Update a single input
nix flake update <input-name>

# Check formatting and evaluate all hosts with real private inputs
nix flake check --all-systems

# Reproduce public CI with dummy private inputs (matches GitHub Actions)
nix flake check --all-systems --show-trace \
  --override-input nixos-secrets path:./ci-dummy-input \
  --override-input nixos-work path:./ci-dummy-input

# Format all files via treefmt (nixfmt, deadnix, statix, yamlfmt, mdformat)
nix fmt

# Deploy to a new machine
nix run github:nix-community/nixos-anywhere -- --flake ~/nixos-config#<hostname> root@<ip>
```

See `README.md` for the full deploy/reinstall flow with sops age keys and `--extra-files`.

## Architecture

Flakes-based NixOS configuration for 6 hosts using the Dendritic pattern: every
file under `modules/` is a flake-parts module, auto-imported by import-tree.
There are no manual import lists.

### Module Composition

`flake.nix` is one line of outputs: `mkFlake (import-tree ./modules)`. Aspect
files define named modules under `flake.modules.nixos.<name>`; several files
can contribute slices to the same name (all of `modules/base/` merges into
`base`). Hosts are aspects too: `modules/hosts/<name>.nix` defines
`flake.modules.nixos."hosts/<name>"` importing a role bundle (`desktop` or
`server`) plus per-host aspects and, for physical
machines, the raw NixOS files from `hosts/<name>/` (hardware, disko, host
fragments; these are plain NixOS modules kept outside `modules/` on purpose).
The `workstation` aspect contains desktop-environment-independent configuration;
`desktop` adds GNOME.
`modules/nixos-configurations.nix` builds `flake.nixosConfigurations` from
every `hosts/*` aspect, constructs the shared `pkgs` (overlays,
`allowUnfree`) once for all hosts, and passes `specialArgs` (`inputs`,
`username` ("kevin"), `hostname`). It also imports
`inputs.flake-parts.flakeModules.modules`, the opt-in flake-parts extra that
provides the `flake.modules` option. Home Manager stays integrated through
`modules/base/users.nix`.

### Aspect pattern

To add a new aspect: create one file under the fitting `modules/` category
defining `flake.modules.nixos.<name>`, then add the name to a role bundle in
`modules/roles/` or to specific hosts in `modules/hosts/<host>.nix`.
Cross-cutting config lives in the aspect file that owns it and contributes
fragments to other module names (e.g. `modules/net/tailscale.nix` also adds
workstation and server variants to the roles). Files or directories prefixed
with `_` are ignored by import-tree.

### Custom options

Some base slices expose typed options (`modules/base/boot.nix` defines
`bootloader.mode` enum bios/uefi, `kernelPackages`, `uefiOSProber`, and
`modules/base/secrets.nix` defines `hostSecrets.enable`). Hosts override these
in `modules/hosts/<host>.nix` (e.g. `uefiOSProber = true` on dual-boot hosts).

### Hosts

| Host | Type | Notes |
| ------- | ------------------- | ------------------------------------------- |
| amdep | Workstation | Full desktop, dual-boot |
| minidesk | Server | Work configuration |
| t14g6 | ThinkPad laptop | Full desktop, TLP, nixos-hardware module |

### Secrets (sops-nix + age)

Secrets live in a separate private repo (`nixos-secrets`) pulled as a non-flake input. `modules/base/secrets.nix`:

- Per-host secrets from `secrets/<hostname>.yaml`
- Shared `user-password` from `secrets/common.yaml`
- SSH auth + signing keys deployed to `~/.ssh/`
- Age key at `/var/lib/sops-nix/key.txt` (shipped via `nixos-anywhere --extra-files` on first deploy)

The private inputs are always declared in `flake.nix`. Public CI evaluates by overriding them with the committed dummy input at `ci-dummy-input`. Secret modules check for real secret files with `builtins.pathExists` before declaring `sops.secrets`, so dummy mode does not point sops at fake paths. Keep new sops integrations behind the same real-file check.

`modules/misc/work.nix` defines the `work` aspect, imported by `modules/roles/desktop.nix`. It imports `nixos-work` as a non-flake input and applies its returned config only when the input is present. The dummy CI input returns an empty module for this path.

## Conventions

- Conventional commits, no commit body/description.
- No em dashes anywhere (use commas/parentheses), no Unicode right arrow symbol (use `->`).
- treefmt enforces format on CI through `nix flake check --all-systems` with dummy private inputs in `.github/workflows/nix-config-check.yml`.

# NixOS Configuration Guide

## Identify the Host

Run `hostname` before you make a host-specific change. If the request does not name a host, use the command output. If the request names a host, use that host.

Use `modules/hosts/<hostname>.nix` as the host entry point. Raw hardware, disk, and host fragments are in `hosts/<hostname>/`.

## Work with Sibling Repositories

The following related repositories are usually cloned next to this repository:

- `nixos-secrets`: `~/nixos-secrets`
- `nixos-work`: `~/nixos-work`
- `nixos-nvim`: `~/nixos-nvim`
- `nixos-pi`: `~/nixos-pi`
- `nixos-hyprland`: `~/nixos-hyprland`

Check the applicable sibling repository when a task changes secrets, work configuration, Neovim, Pi, or Hyprland.

## Work with Dendritic Modules

`import-tree` automatically loads Nix files under `modules/`. Do not add manual imports to `flake.nix`.

An aspect is a named NixOS module under `flake.modules.nixos`. Multiple files can contribute settings to the same aspect.

### Add

Put the file in the correct category under `modules/`. Add settings to an existing aspect, or define a new aspect:

```nix
{
  flake.modules.nixos.example =
    { ... }:
    {
      # NixOS options
    };
}
```

### Attach

Attach a new aspect by adding `config.flake.modules.nixos.example` to an `imports` list:

- `workstation.imports` in `modules/roles/desktop.nix`: all workstation hosts
- `desktop.imports` in `modules/roles/desktop.nix`: all desktop hosts
- `server` imports in `modules/roles/server.nix`: all server hosts
- `modules/hosts/<hostname>.nix`: one host only

Do not add an import when the file adds settings to an aspect that is already imported. Flake-parts merges all files that define the same aspect.

### Modify

Search for the aspect name before you edit it. Change the file that owns the setting. One aspect can have contributors in many files. For example:

```bash
rg 'tailscale' modules
```

### Delete

Search for the aspect name in `modules/`. Remove its imports and references, then delete its definition. If the file contributes to other aspects, keep the file and remove only the target contribution.

## Tests and CI

Keep the existing CI workflow and `ciMode` support. Add tests or new checks only when the user explicitly asks for them.

## Format and Apply

Format the repository:

```bash
nix fmt
```

Apply the configuration only when the user asks for it. Run this command on the target host:

```bash
nh os switch ~/nixos-config
```

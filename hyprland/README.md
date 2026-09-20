# Desktop configuration

This folder owns the shared Hyprland behavior and DankMaterialShell (DMS) interface. Change it for key bindings, window behavior, shell preferences, and local plugin UI. Packages, system services, permissions, and installation wiring belong in `modules/hyprland/` instead.

## Where to make a change

| Path | What belongs here |
| --- | --- |
| `hyprland.lua` | Shared compositor settings, shortcuts, window rules, and workspace behavior |
| `settings.json` | DMS appearance and shell preferences, including changes saved through its UI |
| `plugin_settings.json` | Plugin preferences and enabled state |
| `plugins/` | Local DMS plugin source and UI behavior |
| `patches/` | Changes applied to packaged upstream code when a setting or local plugin cannot provide the behavior |

Machine-specific settings belong in `hosts/<hostname>/hyprland.lua`, not in shared rules with host-name checks. The generated Hyprland entry point loads that host file first, then this folder's `hyprland.lua`.

## Live files versus packaged code

Hyprland reads Lua directly from `~/nixos-config`. DMS settings and plugin preferences are writable links to the JSON files here. UI changes can therefore appear in `git diff`. Review them before committing, and reload the relevant desktop component when needed.

Local plugin source, helper commands, and upstream patches are installed through Nix. Editing those files does not replace the running packaged copy. Rebuild with `just switch` from the repository root and restart the relevant component if needed.

> [!IMPORTANT]
> A Nix generation rollback does not restore live Lua or JSON files. Restore their Git contents separately if you need to undo a desktop change.

## Adding or changing a plugin

Use `plugins/` for a local DMS feature. Its matching module under `modules/hyprland/` installs the plugin and supplies helper executables or service integration. A directory here alone does not install a plugin. Keep external command dependencies in Nix rather than relying on whatever happens to be in the shell's PATH.

Use `patches/` only for changes to upstream packaged behavior. The module that applies a patch owns its build integration. Recheck patches when updating DMS, because upstream source changes can make them fail to apply.

Keep shared preferences in Git. Store per-user history and frequently changing runtime state outside the checkout.

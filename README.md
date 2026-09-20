# NixOS configuration

My NixOS desktops, servers, and development environment. Built on [nixos-unstable](https://github.com/NixOS/nixpkgs), [Home Manager](https://github.com/nix-community/home-manager), and [flake-parts](https://flake.parts/).

Desktops use Hyprland and DankMaterialShell. The repo also contains Neovim configuration, Pi settings and skills, container tools, and self-hosted services.

This is a personal configuration, not a starter template. It targets `x86_64-linux`, uses the account `kevin`, and depends on private secrets and work configuration. Desktop settings expect a checkout at `~/nixos-config`.

## Hosts

| Host | Purpose |
| --- | --- |
| [`amdep`](modules/hosts/amdep.nix) | Hyprland desktop, dual-boot with Windows |
| [`t14g6`](modules/hosts/t14g6.nix) | ThinkPad T14 Gen 6 AMD, Hyprland desktop |
| [`fium`](modules/hosts/fium.nix) | Self-hosted services and storage |
| [`minidesk`](modules/hosts/minidesk.nix) | Development and work server |
| [`installer`](modules/hosts/installer.nix) | Minimal installation ISO |

## Structure

[import-tree](https://github.com/vic/import-tree) loads the files under `modules/`. Features are named NixOS modules called **aspects**. Roles group aspects, and host entry points select the roles and features each machine needs.

| Path | Contents |
| --- | --- |
| [`flake.nix`](flake.nix) | Inputs and module loading |
| [`modules/nixos-configurations.nix`](modules/nixos-configurations.nix) | Host discovery and shared package set |
| [`modules/hosts/`](modules/hosts/) | Host entry points |
| [`modules/roles/`](modules/roles/) | Desktop, workstation, and server roles |
| [`modules/`](modules/) | Feature settings grouped by area |
| [`hosts/`](hosts/) | Hardware, disk layouts, and host-specific desktop files |
| [`hyprland/`](hyprland/) | Desktop configuration, DMS settings, plugins, and patches |
| [`neovim/`](neovim/) | Neovim Lua configuration and Nix wrapper |
| [`pi/`](pi/) | Pi skills, prompts, themes, and maintenance files |
| [`packages/`](packages/) | Local helper packages |
| [`lib/`](lib/) | Shared Nix helpers |
| [`justfile`](justfile) | `just switch` to build and activate the current host |

## Documentation

- [Install a machine](INSTALL.md): new hosts, reinstalls, secrets, and first-boot setup.
- [Public CI](.github/workflows/nix-config-check.yml): checks with dummy private inputs.

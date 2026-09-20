# Neovim

This is the configuration for the Neovim package built by the flake. Nix supplies plugins and command-line dependencies. Lua controls editor behavior and plugin setup. It is not a separate plugin-manager installation in `~/.config/nvim`.

## Which file to change

| File | Change it for |
| --- | --- |
| `init.lua` | Editor options, key bindings, autocmds, plugin configuration, and lazy-load triggers |
| `wrapper.nix` | Installed plugins, Tree-sitter grammars, runtime tools, and language-provider configuration |
| `../modules/neovim.nix` | Exporting the wrapped package and installing it into NixOS configurations |

For a new plugin, add its package to `wrapper.nix` and its setup or load rules to `init.lua` if required. Lua configuration alone does not install a plugin.

Add language parsers and external tools to `wrapper.nix` when the editor needs them. Keep dependencies in the package rather than relying on tools installed separately in the user's shell.

## Using and checking changes

The leader key is Space. Key bindings are maintained in `init.lua`, rather than duplicated here.

From the repository root, `nix build .#neovim` builds this editor without changing the installed system. Run `./result/bin/nvim` to try that build. `just switch` installs it for the current host.

The configuration is included in the Nix package, unlike the live Hyprland files. Rebuild after source changes and start a new Neovim process to use the new package. Do not edit files under `/nix/store` or expect a separate local Neovim checkout to be loaded.

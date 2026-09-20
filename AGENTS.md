# Project rules

- For host-specific changes, run `hostname`. Use the host named in the request, or the current host if none is named.
- Prefer the applicable shared aspect: `base` for all hosts, `server` for servers, or `workstation` for workstations. Put feature choices in `modules/hosts/<hostname>.nix` only when the request explicitly makes them host-specific. Keep hardware and disk files in `hosts/<hostname>/`.
- Extend the existing aspect when possible. An aspect is a named module under `flake.modules.nixos`.
- Attach new aspects to the applicable role by default. Extending an imported aspect needs no extra import.
- `import-tree` loads Nix files under `modules/`. Keep raw NixOS helper modules outside that directory. Do not add manual imports to `flake.nix`.
- Run `nix fmt` after changes. Activate the system only when asked.
- After changes, check whether related documentation needs updating and fix anything made inaccurate.
- Keep documentation focused on purpose, ownership, and stable conventions. Leave changing defaults and shortcut lists in the code.
- Use Conventional Commit messages when asked to commit.

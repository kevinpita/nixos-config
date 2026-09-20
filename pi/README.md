# Pi configuration

This folder owns the Pi configuration content shipped with these systems. It is not the Pi runtime source or the main extension repository. `modules/pi.nix` selects the runtime, extensions, npm packages, generated settings, and files installed into `~/.pi/agent/`.

## What belongs here

| Path | Change it for |
| --- | --- |
| `AGENTS.md` | Shared instructions deployed as the user's Pi instructions. Project-specific rules belong in the relevant project's instruction file. |
| `skills/` | Reusable task guidance and its supporting references. Extend the existing skill when it already owns the task. |
| `prompts/` | Reusable prompt text for tasks the user starts explicitly |
| `themes/` | Pi color themes. The selected theme is set in `modules/pi.nix`. |
| `agents/` | Local agent definitions selected and configured through Nix |
| `extensions/` | The local web/workflow integration bridge, not general extension development |
| `dynamic-workflows/` | The compatibility patch and web-tool support used by that bridge |
| `scripts/` | Session maintenance code packaged and scheduled through Nix |

The skills, prompts, and themes directories are deployed as directories. Agent definitions and local extension files are selected explicitly in `modules/pi.nix`, so adding one here may also need a module change. Keep shared skill content here rather than duplicating it for each configured client.

## Configuration or extension code?

Change `modules/pi.nix` for defaults, package selection, extension settings, or which files are installed. Change this folder for the content of those files. Changes to the main custom extensions belong in `~/nixos-pi`, consumed through the `pi-extensions` flake input. The `pi-flake` input provides the Pi runtime.

For local extension development, override `pi-extensions` with `path:$HOME/nixos-pi` in a check or build. For normal deployment, publish the extension changes and update that flake input. A local clone alone does not change what the locked configuration installs.

The workflow bridge is a deliberate local exception. Change it only for the integration between web tools and workflow agents. Its [existing guide](dynamic-workflows/README.md) explains patch application, update behavior, and what needs verification after an upstream change.

## Applying changes

Run `just switch` from the repository root to deploy Nix-managed changes, then restart Pi to load them. Edit the source here rather than generated or linked files under `~/.pi/agent/`. Prompt filenames become their command names, so rename them only when the user-facing command should change.

Session history, authentication, caches, and generated artifacts are runtime data, not configuration to commit here. The session-maintenance script can archive and remove old sessions, so changes to its retention behavior need particular care.

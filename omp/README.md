# omp configuration

This folder owns the oh-my-pi (omp) harness configuration. `modules/omp.nix` selects the omp package, wraps it with fixed settings, and installs these files into `~/.omp/agent/`. Global instructions and skills do not depend on omp, so they belong in [`agents/`](../agents/README.md).

## What belongs here

| Path | Change it for |
| --- | --- |
| `config.yml` | omp settings shared by all hosts. `~/.omp/agent/config.yml` links to this file, so settings changes in omp edit it in place. Commit and pull to share them. |
| `agents/` | omp worker definitions deployed to `~/.omp/agent/agents`. Their `model` frontmatter selects a role from `config.yml`. |

## Model routing

`config.yml` owns model assignments and reasoning effort. The `task` role selects the model for generic task workers. `task.agentModelOverrides` assigns models to bundled specialists without copying their prompts. Custom workers select roles through their `model` frontmatter.

A session model switch does not change explicit worker assignments. Role aliases resolve at use time. An alias to `@default` can follow a session model switch, so use an explicit selector when a worker must stay on one model.

Keep providers available for manual selection when only their default routes change. Provider blocks belong in `modules/omp.nix`, separate from role assignments.

## Configuration or package?

Change `modules/omp.nix` for the package, wrapper settings that runtime edits must not override, or which files are installed. Change this folder for the content of those files. The `oh-my-pi` flake input provides omp. The `pstack` input pins the pstack plugin that omp loads.

## Applying changes

Run `just switch` from the repository root to deploy Nix-managed changes, then restart omp to load them. Edit the source here rather than linked files under `~/.omp/agent/`.

Session history, authentication, caches, and generated artifacts are runtime data, not configuration to commit here.

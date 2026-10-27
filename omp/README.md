# omp configuration

This folder owns the oh-my-pi (omp) harness configuration. `modules/omp.nix` selects the omp package, wraps it with fixed settings, and installs these files into `~/.omp/agent/`. Global instructions and skills do not depend on omp, so they belong in [`agents/`](../agents/README.md).

## What belongs here

| Path | Change it for |
| --- | --- |
| `config.yml` | omp settings shared by all hosts. `~/.omp/agent/config.yml` links to this file, so settings changes in omp edit it in place. Commit and pull to share them. |
| `agents/` | omp worker definitions. `~/.omp/agent/agents` links to this folder, so agents that omp creates or edits land here. Their `model` frontmatter selects a role from `config.yml`. The `rl-*` workers of the `review-loop` skill use explicit selectors instead, so they keep their reasoning effort. |
| `skills/` | Skills that need omp tools or omp workers. They are installed with the shared skills from `agents/skills` into `~/.omp/agent/skills`, for omp only. |
| `extensions/` | omp extensions installed into `~/.omp/agent/extensions`. `review-loop-guard.ts` blocks `git push` while `~/.omp/agent/review-loop.active` exists. `session-relay.ts` adds `/send <host\|local> <name> [--snapshot]` and `/receive [host] <name>`. `/send` sends a fork of the current session over SSH and keeps the sender in the original. `/receive` installs the fork and switches the terminal to it. SSH always goes from the workstation to the server, so a server stages with `/send local` and the workstation pulls. `session-relay.e2e.sh` tests it in two incus VMs. |
| `WATCHDOG.yml` | The advisor roster: each advisor's name, model, effort, and default on/off state. `~/.omp/agent/WATCHDOG.yml` links to this file, so `/advisor configure` at user scope edits it in place. |

## Model routing

`config.yml` owns model assignments and reasoning effort. The `task` role selects the model for generic task workers. `task.agentModelOverrides` assigns models to bundled specialists without copying their prompts. Custom workers select roles through their `model` frontmatter.

A session model switch does not change explicit worker assignments. Role aliases resolve at use time. An alias to `@default` can follow a session model switch, so use an explicit selector when a worker must stay on one model.

Keep providers available for manual selection when only their default routes change. Provider blocks belong in `modules/omp.nix`, separate from role assignments. Custom providers go into the generated `~/.omp/agent/models.yml`. Their API keys stay outside the repository: the `nan` provider reads its key from `~/.config/nan/api-key`, which sops-nix writes from `nan-key` in the `nixos-secrets` file `secrets/common.yaml`.

## Logins

One host can set `omp.authBroker.enable` to run `omp auth-broker serve` as a system service. That host keeps the logins in its `~/.omp/agent/agent.db` and refreshes the OAuth tokens. The broker listens only on `127.0.0.1:8765`, and Tailscale Serve publishes that port on the tailnet, so no other network can reach it. The wrapper on every other host sets `OMP_AUTH_BROKER_URL` to the MagicDNS name of the broker host, so omp on those hosts ignores its local logins. Sign in on the broker host. All hosts read the shared bearer token from `~/.omp/auth-broker.token`, which sops-nix writes from `omp-auth-broker-token` in the `nixos-secrets` file `secrets/common.yaml`.

## Configuration or package?

Change `modules/omp.nix` for the package, wrapper settings that runtime edits must not override, or which files are installed. Change this folder for the content of those files. The `oh-my-pi` flake input provides omp. The `pstack` input pins the pstack plugin that omp loads.

## Applying changes

Run `just switch` from the repository root to deploy Nix-managed changes, then restart omp to load them. Edit the source here rather than linked files under `~/.omp/agent/`.

Session history, authentication, caches, and generated artifacts are runtime data, not configuration to commit here.

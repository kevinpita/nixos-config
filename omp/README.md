# omp configuration

This folder owns the oh-my-pi (omp) harness configuration. `modules/omp.nix` selects the omp package, wraps it with fixed settings, and installs these files into `~/.omp/agent/`. Global instructions and skills do not depend on omp, so they belong in [`agents/`](../agents/README.md).

## What belongs here

| Path | Change it for |
| --- | --- |
| `config.yml` | omp settings shared by all hosts. `~/.omp/agent/config.yml` links to this file, so settings changes in omp edit it in place. Commit and pull to share them. |
| `agents/` | omp worker definitions. `~/.omp/agent/agents` links to this folder, so agents that omp creates or edits land here. Their `model` frontmatter selects a role from `config.yml`. The `rl-*` workers of the `review-loop` skill use explicit selectors instead, so they keep their reasoning effort unless a spawn sets `effort`. |
| `skills/` | Skills that need omp tools or omp workers. They are installed with the shared skills from `agents/skills` into `~/.omp/agent/skills`, for omp only. |
| `commands/` | File-based slash commands installed into `~/.omp/agent/commands`. `pre-pr.md` adds `/pre-pr`, an adversarial review of the current branch with its working tree, or of a PR, a branch, a commit, or a range: the picked models try to break the change in their own clones, and only findings that a rerun proves go into the report. `pre-pr.sh` does its git steps (snapshot, clones, guard, cleanup); test it with `bash omp/commands/pre-pr.test.sh`. omp loads only the `*.md` files as commands. |
| `extensions/` | omp extensions installed into `~/.omp/agent/extensions`. `review-loop-guard.ts` blocks `git push`, `gh pr create`, and `gh pr merge` in a repository while `review-loop.active` exists in its git common dir. `session-relay.ts` adds `/send <host\|local> <name> [--snapshot]` and `/receive [host] <name>`. `/send` sends a fork of the current session over SSH and keeps the sender in the original. `/receive` installs the fork and switches the terminal to it. SSH always goes from the workstation to the server, so a server stages with `/send local` and the workstation pulls. `session-relay.e2e.sh` tests it in two incus VMs. `focus-view.ts` adds `ctrl+l` and `/focus`, a fullscreen view that shows one answer per prompt, with a spinner while the agent works. After an advisor note, a new message replaces the shown answer only when it starts with the `# Revised answer` heading that `agents/AGENTS.md` asks for. A short reply to the note does not hide the answer. omp reserves `ctrl+l` for its own live voice toggle, so the extension reads raw terminal input and replaces that toggle. |
| `WATCHDOG.yml` | The advisor roster: each advisor's name, model, effort, and default on/off state. `~/.omp/agent/WATCHDOG.yml` links to this file, so `/advisor configure` at user scope edits it in place. |

## Theme

`config.yml` selects the theme `desktop`. `modules/_desktop-themes.nix` makes it from the upstream `titanium` theme with the colors of a desktop theme in `themes/`, so other upstream changes still arrive. Answer text is brighter than thinking text. On desktop hosts, `~/.omp/agent/themes/desktop.json` links to the theme that `theme-set` selects, and omp loads it again on each switch. Other hosts show gruvbox.

## Model routing

`config.yml` owns model assignments and reasoning effort. The `task` role selects the model for generic task workers. `task.agentModelOverrides` assigns models to bundled specialists without copying their prompts. Custom workers select roles through their `model` frontmatter.

`task.enableEffort` lets a caller set `effort` per spawn, overriding the worker's role effort. `/pre-pr` selects a model and effort together and reuses the per-model workers in `agents/`. Separate selections of the same model run independently.

A session model switch does not change explicit worker assignments. Role aliases resolve at use time. An alias to `@default` can follow a session model switch, so use an explicit selector when a worker must stay on one model.

`providers.maxInFlightRequests.nan` caps all Nan models together at 10 in-flight requests across local omp processes that share the config root. Other hosts do not share this limit. A model-specific provider limit can be lower.

Keep providers available for manual selection when only their default routes change. Provider blocks belong in `modules/omp.nix`, separate from role assignments. Custom providers go into the generated `~/.omp/agent/models.yml`. Their API keys stay outside the repository: the `nan` provider reads its key from `~/.config/nan/api-key`, which sops-nix writes from `nan-key` in the `nixos-secrets` file `secrets/common.yaml`.

## NaN usage

`extensions/nan-usage.ts` adds NaN quota reports to `/usage` and `omp usage`. It reads the `nan` provider's model IDs and API-key reference from `~/.omp/agent/models.yml`, so inference and usage keep the same configuration.

The extension uses the NaN dashboard's undocumented `https://cloud-api.nan.builders/api/usage/quota` endpoint. It reports base quotas for configured models and uses each model's period-end timestamp. Rolling windows appear only when the API supplies their usage and budget. Bonus tokens are not included in the base quotas.

The extension works with the auth broker. If the broker has no NaN report, omp fetches the quota locally with the configured key.

## Logins

One host can set `omp.authBroker.enable` to run `omp auth-broker serve` as a system service. That host keeps the logins in its `~/.omp/agent/agent.db` and refreshes the OAuth tokens. The broker listens only on `127.0.0.1:8765`, and Tailscale Serve publishes that port on the tailnet, so no other network can reach it. The wrapper on every other host sets `OMP_AUTH_BROKER_URL` to the MagicDNS name of the broker host, so omp on those hosts ignores its local logins. Sign in on the broker host. All hosts read the shared bearer token from `~/.omp/auth-broker.token`, which sops-nix writes from `omp-auth-broker-token` in the `nixos-secrets` file `secrets/common.yaml`.

## Configuration or package?

Change `modules/omp.nix` for the package, wrapper settings that runtime edits must not override, or which files are installed. Change this folder for the content of those files. The `oh-my-pi` flake input provides omp. The `pstack` input pins the pstack plugin that omp loads.

## Applying changes

Run `just switch` from the repository root to deploy Nix-managed changes, then restart omp to load them. Edit the source here rather than linked files under `~/.omp/agent/`.

Session history, authentication, caches, and generated artifacts are runtime data, not configuration to commit here.

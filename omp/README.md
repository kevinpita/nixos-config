# omp configuration

This folder owns the oh-my-pi (omp) harness configuration. `modules/omp.nix` selects the omp package, wraps it with fixed settings, and installs these files into `~/.omp/agent/`. Global instructions and skills do not depend on omp, so they belong in [`agents/`](../agents/README.md).

## What belongs here

| Path | Change it for |
| --- | --- |
| `config.yml` | omp settings shared by all hosts. `~/.omp/agent/config.yml` links to this file, so settings changes in omp edit it in place. Commit and pull to share them. |
| `extensions/` | omp extensions installed into `~/.omp/agent/extensions`. See [Extensions](#extensions). |
| `commands/` | File-based slash commands installed into `~/.omp/agent/commands`. See [Commands](#commands). |
| `patches/` | Source patches that `modules/omp.nix` applies to the omp package. See [Configuration or package?](#configuration-or-package). |
| `plannotator/` | The npm dependency pins of the [Plannotator](#plannotator) extension. |
| `WATCHDOG.yml` | The advisor roster: each advisor's name, model, effort, and default on/off state. `~/.omp/agent/WATCHDOG.yml` links to this file, so `/advisor configure` at user scope edits it in place. |

## Extensions

| File | What it adds |
| --- | --- |
| `session-relay.ts` | `/send <host\|local> <name> [--snapshot]` and `/receive [host] <name>`, which move a session between hosts. |
| `branch-ref.ts` | `##name` in the prompt: a fuzzy list of the local and remote git branches that inserts "branch `name`" so the model reads it as a branch. It is off in drafts that omp runs as shell or Python code. |
| `model-preset.ts` | [`/preset`](#model-presets), a model preset switch for one session. |
| `k8s-status.ts` | The kubectl context and namespace in the omp status line. It reads the files in `KUBECONFIG`, so it follows `kubie ctx` and `kubie ns`. |
| `emphasis/` | [Reply emphasis](#reply-emphasis): pills, label icons, and colored bold text. |

`/send` sends a fork of the current session over SSH and keeps the sender in the original. `/receive` installs the fork and switches the terminal to it. SSH always goes from the workstation to the server, so a server stages with `/send local` and the workstation pulls. `session-relay.e2e.sh` tests it in two incus VMs.

## Commands

omp loads only the `*.md` files in `commands/` as commands.

| File | Command |
| --- | --- |
| `pre-pr.md` | `/pre-pr`, an adversarial review of a branch, a PR, a commit, or a range. |
| `impeccable.md` | `/impeccable`, the name that the `impeccable` skill uses for itself. |
| `explainer-video.md` | [`/explainer-video`](#explainer-video) for narrated Manim videos. |
| `tldr.md` | `/tldr`, a 2- or 3-sentence version of the last answer. Its `side: true` frontmatter makes it a `/btw` side question, so it stays off the transcript and can run while a turn streams. |
| `ask.md` | `/ask <question>`, an answer in the transcript with read-only research and no change. |

`/pre-pr` reviews the current branch with its working tree, or a PR, a branch, a commit, or a range. The models you tag with `^` try to break the change in their own clones, and only findings that a rerun proves go into the report. `pre-pr.sh` does its git steps (snapshot, clones, guard, cleanup). Test it with `bash omp/commands/pre-pr.test.sh`.

## Explainer video

Build the offline media runtime once from this repository root:

```sh
mkdir -p "$HOME/.cache/omp/explainer-video"
nix build .#explainer-video-env --out-link "$HOME/.cache/omp/explainer-video/runtime"
```

Deploy the command and skill with `just switch`, then restart omp. In the directory where the output should go, run `/explainer-video Estimar pi con puntos in Spanish from Spain`. The command writes the checked MP4 to `videos/`. The [explainer skill](../agents/skills/explainer-video/SKILL.md) owns the storyboard format, render steps, and job files. The package in `packages/explainer-video/` owns the tools and voice pins. The build can fetch dependencies. The runtime runs the media tools without network access.

To run the audio and mux fixtures from this repository:

```sh
"$HOME/.cache/omp/explainer-video/runtime/bin/explainer-video-env" \
	python3 -B agents/skills/explainer-video/test-video.py
```

## Theme

`config.yml` selects the theme `desktop`. `modules/_desktop-themes.nix` makes it from the upstream `titanium` theme with the colors of a desktop theme in `themes/`, so other upstream changes still arrive. Answer text is brighter than thinking text. On desktop hosts, `~/.omp/agent/themes/desktop.json` links to the theme that `theme-set` selects, and omp loads it again on each switch. Other hosts show gruvbox.

## Reply emphasis

`extensions/emphasis/` is a self-contained, display-only OMP package adapted from pi-emphasis. It owns pills, label icons, and colored bold text without adding prompt instructions. The native assistant text hook uses its renderer. Stored messages and exports keep the original Markdown.

See its [package documentation](extensions/emphasis/README.md) for controls, ownership, and focused checks.

## Model routing

`config.yml` owns the default model assignments and reasoning effort. The `task` role selects the model for generic task workers. `task.agentModelOverrides` assigns models to bundled specialists without copying their prompts.

There are no custom worker agents. To run a worker on a model, tag the model with `^provider/model` in the prompt. Add `:level` to pin its initial reasoning level, for example `^anthropic/claude-opus-5-5:high`. A tag without a level keeps the level that omp uses without one. Upstream omp supports the suffix and its completion: type `^opus:` before accepting a model completion to list matching models and their supported levels.

A tagged worker has no fallback model for provider errors, such as capacity or rate limits. It retries its own model and then fails with an error that names that model. The main session has no fallback either. `modules/omp.nix` fixes this with an empty `retry.fallbackChains.default`, which a runtime settings edit cannot change. The chains of the named roles, such as `task` and `advisor`, stay in `config.yml`. One path stays open: when the tagged model has no usable login at spawn time, omp starts the worker on the main session's model and reports no error.

`task.enableEffort` is `false`, so a caller cannot set `effort` per spawn. The `effort` field would map `lo`, `med`, and `hi` to the lowest, middle, and highest level of the model, so `hi` would run at `max`.

A session model switch does not change explicit worker assignments. Role aliases resolve at use time. An alias to `@default` can follow a session model switch, so use an explicit selector when a worker must stay on one model.

`providers.maxInFlightRequests.nan` caps all Nan models together at 10 in-flight requests across local omp processes that share the config root. Other hosts do not share this limit. A model-specific provider limit can be lower.

Keep providers available for manual selection when only their default routes change. Provider blocks belong in `modules/omp.nix`, separate from role assignments. Custom providers go into the generated `~/.omp/agent/models.yml`. Their API keys stay outside the repository: the `nan` provider reads its key from `~/.config/nan/api-key`, which sops-nix writes from `nan-key` in the `nixos-secrets` file `secrets/common.yaml`.

### Model presets

`config.yml` also holds the named presets under `modelPresets`. There are two ways to switch:

- `/preset [name]` switches the current session only, and `config.yml` does not change. Without a name, it shows a list. The session records the preset, so a resumed session gets its roles back. A new session or a fork in the same omp process stays on the preset.
- `/modelpreset switch <name>` is the built-in command. It writes the roles into `config.yml`, so use it to change the default for all sessions, and commit the result.

`/preset` keeps the roles in the runtime layer that `--model` and `--smol` use. It imports omp internals that the extension API does not cover, so check it after an omp update: `omp -p -e omp/extensions/model-preset.ts "/preset <name>"` must leave `config.yml` unchanged.

## Command approval

`modules/omp.nix` generates a `bash.patterns` overlay. omp asks before a `kubectl` or `helm` command that changes a cluster and before `git push`, also when a flag comes before the verb (`git -C dir push`) or the command runs inside `bash -c`. A headless subagent cannot answer, so it gets a refusal. Change the rules there, not in `config.yml`, so a settings edit cannot remove them.

The rules are an approval policy, not containment. They do not cover `eval` or a verb that is not listed. A command that only contains the text of a listed command also asks, and so does `git -C dir stash push`.

## Plannotator

OMP loads the pinned Plannotator extension in every session. Use `/plannotator-plan-mode` to review plans in a browser. The extension also provides code review and document annotation commands. Its npm dependencies are pinned in `plannotator/package-lock.json`. `modules/omp.nix` replaces its one use of the pi-tui key helper, which omp no longer provides.

## Logins

One host can set `omp.authBroker.enable` to run `omp auth-broker serve` as a system service. That host keeps the logins in its `~/.omp/agent/agent.db` and refreshes the OAuth tokens. The broker listens only on `127.0.0.1:8765`, and Tailscale Serve publishes that port on the tailnet, so no other network can reach it. The wrapper on every other host sets `OMP_AUTH_BROKER_URL` to the MagicDNS name of the broker host, so omp on those hosts ignores its local logins. Sign in on the broker host. All hosts read the shared bearer token from `~/.omp/auth-broker.token`, which sops-nix writes from `omp-auth-broker-token` in the `nixos-secrets` file `secrets/common.yaml`.

## Configuration or package?

Change `modules/omp.nix` for the package, wrapper settings that runtime edits must not override, or which files are installed. Change this folder for the content of those files. The `oh-my-pi` flake input provides omp. The `pstack` input pins the pstack plugin package. `modules/omp.nix` also owns the skill catalog and the pstack plugin that omp and Antigravity CLI share. See [`agents/README.md`](../agents/README.md) for where each harness reads them.

The package applies two source patches for `/fork pane` and `/fork tab`. If an `oh-my-pi` update makes a patch fail to apply, port it to the new source.

- `patches/herdr-core-fork.patch` makes them work in Herdr Desktop and Core. It ports [upstream PR #19201](https://github.com/can1357/oh-my-pi/pull/19201), which upstream closed without a merge, and it holds only the source changes.
- `patches/fork-without-running-turn.patch` applies on top of it. While a response runs, the fork opens without a confirmation and ends at the last finished answer, so it holds nothing of the running turn. The original session continues. During the first response there is no finished answer, so the command reports an error.

## Applying changes

Run `just switch` from the repository root to deploy Nix-managed changes, then restart omp to load them. Edit the source here rather than linked files under `~/.omp/agent/`.

Session history, authentication, caches, and generated artifacts are runtime data, not configuration to commit here.

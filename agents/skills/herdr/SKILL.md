---
name: herdr
description: Herdr window (herdr-app) and its terminals (hc). Use to open work for the user in Herdr, such as a worktree, repo, agent, or server, to run sub-agents or background commands, to read or control terminals, to work on another machine, or to change Herdr layouts and mods. Prefer it over your own sub-agent tool, shell '&', nohup, or tmux.
---

The user works in the Herdr window on a workstation. herdr-core (`hc`) runs the terminals on each machine, and the window shows them. Agents run on the workstation or on servers, for example `minidesk`. There is no `herdr` command.

Before you use `hc`, run `hc --skill` and follow it. Before you use `herdr-app`, run `herdr-app --skill` and follow it.

## Choose by who uses the result

- **The user**: the user asks you to open or start something to work in, for example a worktree, a repo, an agent, or a server. Show it in the window. A worktree or a repo gets a new space. An agent or a server gets a new tab in your space.
- **You**: you start something for your task, for example a helper agent, a test run, or a server for your checks. Start it as an `hc` child terminal.

Give the user a space or a tab, not an `hc` child terminal. The window shows a child only as a row under your tab, and the child stops when your terminal stops.

Leave new spaces and tabs without a name. A worktree space then follows its checkout and nests under its repo, as the branch picker does. A service names each tab after its agent or program. A shell tab keeps its number. This rule wins over the naming advice in `herdr-app --skill`.

## Find how to reach the window

1. If `$HC_TERMINAL_ID` is not set, you do not run in herdr-core. Ask the user once in this session whether to use `hc`.
1. Run `herdr-app status`. If it succeeds, the window runs on this machine. Make the space or tab with `herdr-app do space.new` or `herdr-app do tab.new`.
1. If not, run `hc get "$HC_TERMINAL_ID"`. If its labels include `herdr.space`, the window shows this machine. Make the space or tab with labels, as the next section shows. Your space id is the `herdr.space` label.
1. If not, the window does not show you. Give the user the path or the command to open.

## Open a space or a tab with labels

Servers do not have `herdr-app`. The window shows each terminal that has the labels `herdr.space` and `herdr.tab`. An id that the window does not know makes a new space or tab. Write the ids without the `<machine>/` prefix that the window adds.

```sh
# Set worktree, repo, and task first.
id=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
# Either a new space for a worktree, with a shell:
hc run --bg --no-parent --label "herdr.space=sp$id" --label "herdr.tab=tb$id" --cwd "$worktree"
# Or a new tab in your space, with an agent:
space=$(hc get "$HC_TERMINAL_ID" | jq -r '.labels["herdr.space"]')
hc run --bg --no-parent --label "herdr.space=$space" --label "herdr.tab=tb$id" --cwd "$repo" -- omp "$task"
```

- Without a program, `hc run` starts the shell of the machine.
- `--no-parent` gives the terminal to the user. It does not stop when your terminal stops.

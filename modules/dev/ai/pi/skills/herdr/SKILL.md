---
name: herdr
description: >-
  Use only when HERDR_ENV=1. Control Herdr and orchestrate visible Claude,
  Codex, Pi, or other coding-agent terminals when the user mentions Herdr, asks
  to inspect or control Herdr workspaces/tabs/panes, asks for fake or simulated
  subagents, requests pane-based agents or a visible agent team, or wants work
  delegated to Claude/Codex/Pi in terminal tabs. For agent teams, place at most
  four agent panes in each dedicated tab and create more tabs as needed.
compatibility: >-
  Pi 0.80 or newer, Herdr 0.7.3 or newer, and Pi running in a Herdr-managed pane
  with the pi-herdr package enabled.
metadata:
  source: https://github.com/ogulcancelik/herdr
  pi-package: npm:@ogulcancelik/pi-herdr
---

# Herdr

Use Herdr as an agent-aware terminal multiplexer and, when explicitly requested, as a visible substitute for native subagents. Herdr organizes terminals as workspaces, tabs, and panes. Claude, Codex, Pi, and other agents remain real interactive processes whose state and output can be inspected.

## Activation gate

Before any Herdr control operation, verify this Pi process is inside Herdr:

```bash
test "${HERDR_ENV:-}" = 1 && test -n "${HERDR_PANE_ID:-}"
```

If this fails, explain that the current Pi session was not launched in a Herdr pane. Do not control a separately focused Herdr session from outside it. Ask the user to start or attach Herdr and launch Pi there.

Use this workflow only when the user explicitly requests Herdr or describes a Herdr-specific pane/tab agent workflow. Do not replace every ordinary background task or every native subagent opportunity with Herdr.

## Prefer the Pi Herdr tool

The `@ogulcancelik/pi-herdr` package registers a structured `herdr` tool only when `HERDR_ENV=1` and `HERDR_PANE_ID` are present. Prefer that tool for common safe operations:

- `current`, `list`, `agent_list`, `agent_get`
- `workspace_list`, `workspace_create`, `workspace_focus`
- `tab_list`, `tab_create`, `tab_focus`
- `pane_split`, `pane_rename`, `focus`, `stop`
- `run`, `send`, `read`, `watch`, `wait_agent`

Use the installed CLI for capabilities not exposed by the tool, including worktrees, pane moves, resizing, zoom, direct terminal attach, notifications, integrations, and session administration.

Never run bare `herdr` for command discovery because it launches or attaches the TUI. The installed binary is authoritative. Inspect safe command groups instead:

```bash
herdr --help
herdr pane
herdr tab
herdr workspace
herdr worktree
herdr wait
herdr agent
herdr terminal
herdr integration
herdr session
```

Do not probe a potentially mutating nested command by omitting its arguments. Some create commands are valid with defaults and execute immediately.

## Stable caller context

Herdr sets these variables in managed panes:

```bash
printf '%s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"
```

Public IDs look like `w1`, `w1:t1`, `w1:p1`, and `term_...`, but their suffixes are opaque. Always parse IDs from tool or JSON responses. Never construct an ID from display numbers or examples.

Prefer caller-aware operations such as `current` and `--current`, or pass `$HERDR_PANE_ID` explicitly. Omitting a target can select a pane focused by another client.

Preserve the user's focus by default. Use `focus: false` in the Pi tool or `--no-focus` in the CLI unless the user asks to switch.

## Agent teams as simulated subagents

A Herdr agent team is process-level delegation, not native Pi subagent execution. Child agents do not automatically inherit the parent transcript, task list, tool state, or conclusions. Every assignment must include enough context to work independently, and the coordinator must read and synthesize each result.

When the user asks for fake subagents, simulated subagents, a Herdr agent team, or several Claude/Codex/Pi workers:

1. Keep this Pi pane as the coordinator.
1. Determine the tasks, agent executable for each task, cwd, edit policy, and expected result.
1. Reuse the current workspace unless the user asks for another workspace.
1. Create dedicated background tabs for workers.
1. Put at most four agent panes in each worker tab.
1. Create `ceil(worker_count / 4)` tabs, for example `agents-1`, `agents-2`.
1. Keep all worker tabs unfocused unless the user asks to watch them.
1. Start each agent interactively, wait for its prompt, then submit its assignment atomically.
1. Monitor recognized agent state, handle blocked workers, and read transcripts when complete.
1. Synthesize results in the coordinator pane. Do not merely point the user at raw pane output.

Do not use Pi's native `subagent` tool in parallel with a simulated Herdr team unless the user explicitly asks to mix both systems.

### Pane allocation, maximum four per tab

Each new tab starts with one root pane, which is worker 1. Add panes in this order to produce a usable layout:

- Worker 2: split the root pane right.
- Worker 3: split the root pane down.
- Worker 4: split worker 2 down.

For more than four workers, create another dedicated tab and repeat. Never place worker 5 in the first tab.

Use descriptive, unique aliases such as `research-api`, `review-tests`, or `implement-auth`. Include the tab number only when needed to avoid collisions.

With the structured tool, a two-tab team can be built from `tab_create` and `pane_split` actions. Read each returned root pane or alias before splitting it. With the CLI, parse `.result.tab.tab_id`, `.result.root_pane.pane_id`, and `.result.pane.pane_id` from each JSON response.

### Choose agents

Honor the requested executable. Common interactive commands are:

- Claude Code: `claude`
- Codex: `codex`
- Pi: `pi`
- OpenCode: `opencode`
- OMP: `omp`

If the user requests workers but does not choose agents, ask only when the choice materially matters. Otherwise use Pi workers for Pi-specific tasks and use a mixed Claude/Codex/Pi team for independent reviews where model diversity is useful.

Launch only the normal interactive executable. Do not pass the task as an argv prompt and do not add non-interactive flags unless the user asks for that mode.

### Assignment contract

Send every worker a compact assignment containing:

- objective and exact scope
- cwd or worktree
- files or symbols to inspect
- whether it is read-only or may edit
- constraints and commands to run
- expected output format
- instruction not to spawn more Herdr agents

Example:

```text
Act as a read-only reviewer. In /path/to/repo, inspect the current diff for correctness and missing tests. Do not edit files and do not spawn other agents. Return only actionable findings with file and line references, then wait.
```

For a writer, state exclusive ownership clearly:

```text
You are the sole writer for files X and Y in this worktree. Implement the requested change, run the focused checks, and summarize edits and remaining risks. Do not edit outside that scope and do not spawn other agents.
```

### Safe write ownership

Multiple interactive agents in the same checkout can overwrite each other. Follow one of these patterns:

- Same cwd: one writer, all other workers are read-only reviewers or researchers.
- Parallel writers: create a separate Herdr-managed Git worktree and cwd for each worker.
- Disjoint files in one cwd: use only when the user explicitly accepts the risk and ownership boundaries are unambiguous.

For worktrees, inspect `herdr worktree` and use the installed CLI syntax. Do not invent worktree command arguments. Record which pane owns which worktree and do not remove it until its result is integrated or the user asks for cleanup.

## Start and prompt a worker

After creating and labeling a pane, start its interactive executable with `run`. The initial `run` is the agent command, for example `codex`.

Inspect the pane. A recognized agent normally reaches `idle` at its initial prompt. Wait for that state before submitting the assignment with another atomic `run` action.

Equivalent CLI flow:

```bash
herdr pane run <pane-id> codex
herdr wait agent-status <pane-id> --status idle --timeout 30000
herdr pane run <pane-id> "<assignment>"
```

`pane run` sends text and Enter together. Use literal `send` or `send-text`/`send-keys` only for control keys, confirmations, or input that must not include Enter.

## Monitor and collect

Agent states are:

- `working`: processing
- `blocked`: waiting for input, a question, or approval
- `done`: completed while unseen
- `idle`: waiting or completed and considered seen
- `unknown`: no recognized state

Treat both `idle` and `done` as completion after a worker has entered `working`. `done` and `idle` differ by attention state, not by result quality.

For several workers, wait until every pane is in either `idle` or `done`:

```json
{
  "action": "wait_agent",
  "panes": ["research-api", "review-tests"],
  "statuses": ["idle", "done"],
  "mode": "all",
  "timeout": 120000
}
```

If a wait times out, inspect current state and output instead of assuming failure. For `blocked`, read the recent transcript, answer only when safe and authorized, or ask the user. For `unknown`, verify that the executable launched and that Herdr recognizes it.

Read agent results with `recent-unwrapped`, usually 80 to 160 lines. Use `detection` only to debug state recognition. Use `watch` for ordinary commands, servers, tests, or builds, not for coding-agent completion.

After reading every transcript:

1. Check whether each worker fulfilled its assignment.
1. Send a focused follow-up if evidence is missing.
1. Reconcile conflicting findings.
1. Apply or integrate changes through the designated writer.
1. Run coordinator-side validation when appropriate.
1. Report a single synthesized result with remaining risks.

## Integrations and state debugging

Herdr can detect common agents from foreground processes and screen manifests. Direct integrations improve lifecycle state or native session restore. Inspect before changing them:

```bash
herdr integration status
herdr agent list
herdr pane read "$HERDR_PANE_ID" --source recent --lines 50
herdr agent explain "$HERDR_PANE_ID"
```

Install integrations only when requested or during explicit setup:

```bash
herdr integration install pi
herdr integration install claude
herdr integration install codex
```

The Pi integration reports lifecycle state and session identity. Claude and Codex integrations add native session identity while their visible state remains screen-manifest driven.

For an agent behind a Linux sandbox or VM wrapper that hides the foreground process, scope the detection hint to that command:

```bash
HERDR_AGENT=claude fence -- claude
```

Do not export `HERDR_AGENT` globally.

## Cleanup and safety

- Never close the coordinator pane.
- Close only panes, tabs, worktrees, or workspaces created for this request.
- Leave worker panes open by default so the user can inspect or continue them. Clean up only when requested or clearly agreed.
- Never close user-owned contexts merely because they appear idle.
- Never run `herdr server stop` or kill the main Herdr process unless the user explicitly asks to stop the session server.
- Inspect current output before waiting for future output.
- Use explicit IDs or aliases and parse all created IDs from responses.
- Do not send approvals, destructive commands, secrets, or credentials to a worker without user authorization.

## Authoritative references

- Herdr docs: <https://herdr.dev/docs/>
- Agent model: <https://herdr.dev/docs/agents/>
- Integrations: <https://herdr.dev/docs/integrations/>
- CLI reference: <https://herdr.dev/docs/cli-reference/>
- Pi package: <https://www.npmjs.com/package/@ogulcancelik/pi-herdr>

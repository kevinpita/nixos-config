---
description: Adversarial pre-PR review. Picked models try to break the branch, and only findings proven by a rerun survive.
argument-hint: '[target or focus]'
---

Run an adversarial pre-PR review. The method is the pstack `interrogate` skill: adversaries try to break the change, and a finding survives only when a run proves it. This command replaces its model roster with a picker and adds focus lenses. Report the findings. Do not fix them, commit, or push.

User hint: $ARGUMENTS

## 1. Scope

`~/.omp/agent/commands/pre-pr.sh` does every git step. Call it `pre-pr.sh` below. Its subcommands print `key=value` lines, keep their state in the run folder, and exit non-zero with a `pre-pr:` message on any problem. Shell variables do not survive between `bash` calls, so write the literal run folder path into every later call, quoted.

1. Pick the target from the user hint and run `pre-pr.sh prepare <target>` in the repository:

   | Hint | Target |
   | --- | --- |
   | none | `current`: the current branch with its working tree, against the default branch |
   | a PR number or URL | `pr <number or URL>`, with the URL unchanged |
   | a branch | `branch <name>` |
   | a commit | `commit <rev>` |
   | a range | `range <a>..<b>`: the commits of `git log <a>..<b>` |

1. When it fails, show its message to the user and stop. It refuses, for example, a shallow repository, a dirty submodule, a nested repository that is not a submodule, or a working tree that `git add -A` cannot read.

1. Record `run`, `base`, `head`, `diff`, and `size` from the output, and tell the user every `note` line.

1. State the intent of the change in two or three sentences, from the user hint, the commit subjects (`git log --oneline <base>..<head>`), and the PR description if `gh pr view` finds one. When the intent is unclear, ask the user.

From here on, every exit path goes through §7, also a stop.

## 2. Picker

Ask both questions in one `ask` call.

1. **Models and effort** (`multi: true`). Options, in this order. Mark Claude Opus 5.5 (medium) as recommended. Write "Default" in the descriptions of GPT-6.1 Sol (high) and Claude Opus 5.5 (medium). When the user picks nothing, use those two.

   | Label | Agent | Effort | Selection ID |
   | --- | --- | --- | --- |
   | GPT-6.1 Sol (high) | `gpt` | `high` | `gpt-high` |
   | Claude Opus 5.5 (medium) | `opus` | `medium` | `opus-medium` |
   | Claude Opus 5.5 (high) | `opus` | `high` | `opus-high` |
   | GPT-6 Astra (high) | `astra` | `high` | `astra-high` |
   | GLM-5.3 (high) | `glm` | `high` | `glm-high` |
   | DeepSeek V4 Flash (high) | `deepseek` | `high` | `deepseek-high` |

   Each selected row is independent. Selecting both Opus rows starts separate reviewers at their respective effort levels.

1. **Depth.** `Standard`: one general adversary per selection. `Deep`: a general adversary and two lens adversaries per selection. Recommend `Deep` when `size` shows more than about 300 changed lines or touches state, I/O, concurrency, or security. Otherwise recommend `Standard`.

## 3. Clones

Run `pre-pr.sh clones '<run>' <selection-id>-<lens>...` with one name per adversary, for example `gpt-high-general opus-medium-general opus-high-general`. Each adversary gets its own clone of the head SHA, at `<run>/clones/<name>`. A clone has its own refs, stash, config, index, and hooks, and no remote, so git commands in it cannot change your repository. The command also records the guard state of your checkout.

Tell the user not to edit the repository and not to run `git gc` in it until the report is ready.

## 4. Fan out

Spawn every adversary in one `task` batch. Set `agent` and `effort` from its selected row. Derive a unique CamelCase task name from the selection ID and lens, for example `OpusMediumGeneral` or `OpusHighGeneral`. Do not set `model`.

`context`, the same for every adversary: the intent, the base SHA, the head SHA, the `diff` path, the project rule files (for example `AGENTS.md`), and this brief:

> Break this change. Your clone is not your starting directory: run every command with `cd <clone> &&` or absolute paths inside it. Prove each finding with a run against the real code in your clone, such as a failing test, a repro script, or command output that shows the wrong behavior. For a design or plan, run a prototype or probe the tree. Keep all files and repros in your own clone, and never change another checkout. Report each finding with a title, the exact command, the working directory, the output it printed, and the output the intent requires. Leave out anything you did not run. That covers style, naming, structure, and risks that need a future change to matter. No findings is a valid result. End with the areas you attacked and `Status: COMPLETE` or `Status: INCOMPLETE` with the reason.

`task` per adversary: its clone path and its lens.

| Lens | Attack |
| --- | --- |
| General | Anything that breaks the intent. |
| Inputs | Boundaries, empty, huge, and malformed inputs, API and protocol contracts, compatibility with existing callers and data. |
| State | Concurrency and ordering, failure paths and error handling, retries, partial writes, resource leaks, security. |

`Standard` spawns the General lens per selection. `Deep` spawns all three lenses per selection.

## 5. Verify

1. For each finding, run its command again in that adversary's clone. Keep the finding when the output shows the failure and the failure breaks the intent. Drop the rest and record why.
1. Merge findings that share a root cause. Keep the list of model-and-effort selections and lenses that found each one.
1. A failed or `INCOMPLETE` adversary never counts as a clean result. Name it in the report.
1. Run `pre-pr.sh guard '<run>'` after the reruns, so it covers them too. Exit 0 prints `unchanged`. Exit 3 prints a diff: your checkout changed during the run, by an adversary or by the user. Put the diff in the report under **Checkout changed** and tell the user. Any other exit is an error: say that the guard did not run.

## 6. Report

Write `<run>/report.md` and show it to the user:

- **Verdict** on the first line: `Not ready` when a finding survives. Else `Incomplete` when any adversary failed or returned `Status: INCOMPLETE`. Else `Ready for PR`.
- **Intent**: the restatement.
- **Findings**, most severe first. For each: what breaks in one sentence, location, the command, its output, how it breaks the intent, and the model-and-effort selections and lenses that found it. Write "No verified findings" when none survive.
- **Dropped**: for each adversary, the count of dropped findings and why.
- **Coverage**: the target, the base and head SHAs, the picked model-and-effort selections, the depth, any adversary that failed or stopped early, the `note` lines, and the guard result. The guard does not cover ignored files, intent-to-add flags, or submodule content.

## 7. Cleanup

Run `pre-pr.sh cleanup '<run>'` on every exit path, also after a stop. It removes the clones and keeps `<run>/report.md`. The snapshot commit has no ref, so `git gc` removes it later.

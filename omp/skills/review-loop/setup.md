# Setup

Ask one question at a time with `ask`. Build each picker from facts you collected, so that the user picks instead of types. Other stays available for typed answers. Use the optional hint from the start command to put the matching option first and to mark it recommended. Skip a question only when the hint answers it exactly, and show that answer in the confirmation.

## Facts to collect first

- `git rev-parse --show-toplevel`, `git branch --show-current`, `git status --porcelain`.
- Default branch: `git symbolic-ref --short refs/remotes/origin/HEAD`, else `main` or `master` if it exists.
- `git log --oneline -5`.
- Open PRs, if `gh` works: `gh pr list --limit 10 --json number,title,headRefName`.
- Push guard: `~/.omp/agent/extensions/review-loop-guard.ts` exists.

## Models

| Key | Label | Read agent | Fix agent |
| --- | --- | --- | --- |
| `opus` | Claude Opus 5.5 | `rl-read-opus` | `rl-fix-opus` |
| `gpt` | GPT-6.1 Sol | `rl-read-gpt` | `rl-fix-gpt` |
| `fable` | Claude Fable 5.1 | `rl-read-fable` | `rl-fix-fable` |
| `glm` | GLM-5.3 | `rl-read-glm` | `rl-fix-glm` |
| `deepseek` | DeepSeek V4 Flash | `rl-read-deepseek` | `rl-fix-deepseek` |

## Questions, in order

1. **Target.** Options: `Current branch <name> vs <default>` (when not on the default branch), each open PR as `PR #<n>: <title>` (the PR of the current branch first), `Last commit <sha> <subject>`, `Commit range...`. Other: a branch, a PR number or URL, or a SHA.
1. **Dirty tree**, only when `git status --porcelain` is not empty. Fix commits need a clean main checkout. Options: `Commit as WIP first`, `Stash`, `Stop`.
1. **Checkout**, only when the target is not the checked-out branch. Fixes need it checked out locally. Options: `Check it out here` (`gh pr checkout <n>` or `git switch <branch>`), `Stop`.
1. **Base**, for a branch, PR, or range target. Options: the default branch, the PR base branch, the upstream branch. After the checkout, pin `git merge-base <base> HEAD` as the base SHA. A single commit target pins `<sha>^`.
1. **Mode.** `Human`: you are asked when a finding needs a choice, and you always give the reason. `Auto`: judge models decide and record their reasons. You are asked only when they stay split after 3 exchanges.
1. **Reviewers** (`multi: true`). Recommend Opus + GPT.
1. **Validators** (`multi: true`). Recommend Opus + GPT.
1. **Fixers** (`multi: true`). Recommend Opus + GPT. Each fixer works in its own git worktree.
1. **Judges** (`multi: true`), auto mode only. Recommend Opus + Fable.
1. **Squash scope.** `Loop fixes only`: squash the loop's fix commits into one commit on top of the start HEAD. `Whole branch`: squash everything since the base SHA into one commit.
1. **Focus.** Options: `No extra focus`, plus 2-3 focus areas you infer from the diff. Other: free text.
1. **Confirm.** Show every answer, the base SHA, the start HEAD, and the agents per stage. Options: `Start`, `Change an answer`. For a change, ask which answer, then ask that question again.

## After the confirmation

1. Write the ledger Setup section.
1. Run `touch ~/.omp/agent/review-loop.active`. If the guard extension is missing, tell the user that pushes are not blocked by a hook in this session.
1. Check that `git status --porcelain` is empty.

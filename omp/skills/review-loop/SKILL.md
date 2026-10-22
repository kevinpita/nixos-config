---
name: review-loop
description: Multi-model review -> validate -> fix loop with fresh-context children, local commits, a final squash, and a final review.
disable-model-invocation: true
---

# Review Loop

Start with `/skill:review-loop`. Text after the command is an optional hint for setup, never a replacement for it.

You are the **orchestrator**. You own the scope, the ledger, every decision, every commit in the main checkout, and the final verdict. Children review, validate, judge, and fix. Every child is **fresh**: it gets its stage brief and the inputs that its stage names, nothing else. Never send a child your conversation, earlier rounds, or the whole ledger. Never message an agent from an earlier round. Inside one stage of one round, you message that stage's agents only through Consensus.

Open one todo per step below before you start.

## Ledger

The ledger is the single source of truth and your memory. It is `local://review-loop/ledger.md`. Write it at setup. Update it after every step. After a compaction, read it again before you act.

Sections:

- **Setup**: every setup answer, pinned base SHA, start HEAD SHA, main checkout path.
- **Decisions**: every decision by the user or by the judges, with the reason in the decider's own words, the finding IDs it covers, and who decided. A reason says *why*, not only *what*.
- **Findings**: one row per finding: `RL-<n>`, title, location, raised by (models), status, decision ref, fix commit, rounds seen. Status is one of `open`, `confirmed`, `rejected`, `needs-decision`, `approved`, `ignored`, `fixed`, `unresolved`.
- **Rounds**: per round: HEAD SHA, agents spawned with their `agent://` IDs, counts per status, commits made.

Match a new finding to an old one by underlying problem and scope, not by wording or line number. A changed failure or scope is a new finding.

## Consensus

Run [consensus.md](consensus.md) after every stage that ran with two or more models, before you use its result. Items that stay split after 3 exchanges go to the user in both modes.

## Reasons

A reason from the user is in the user's own words. Ask with one question whose `options` list is empty, so that the only answer is typed text. Put the decision in the question text. An empty answer, or an answer with `timedOut`, is no answer: ask again. Never offer a drafted reason as an option.

## 1. Setup

Read [setup.md](setup.md) and follow it.

**Done:** the user confirmed the summary, the ledger Setup section is written, the push guard is active, and the main checkout is clean.

## 2. Review (round N)

1. Write the current change to `local://review-loop/round-N/diff.patch` with `git diff <base SHA>..HEAD`, for every target kind. It includes the fix commits of earlier rounds. Record HEAD.
1. Spawn one reviewer per review model in one `task` batch. Agent: `rl-read-<model>`. `context`: the full text of [briefs/review.md](briefs/review.md), the repository path, the target description, base and head SHAs, the diff path, the project rule files (for example `AGENTS.md`), and the user's focus. Every reviewer gets the same `task`.
1. Run Consensus on the findings.
1. Merge the results. Collapse duplicates and keep the models that raised each one.

**Done:** every reviewer returned `Status: COMPLETE`, or you recorded the failure and stopped the round. `git status --porcelain` in the main checkout equals its state before the stage.

## 3. Filter with the ledger

For each merged finding:

- It matches an `ignored` finding and the recorded reason still covers it -> drop it and count it.
- It matches a `fixed` finding -> keep it and mark it `REGRESSION`.
- A recorded reason is relevant but does not clearly cover it -> keep it and attach the reason, quoted, as an annotation.
- It is new -> add it to the ledger as `open`.

**Done:** every merged finding is dropped, annotated, or new, and the ledger shows it.

## 4. Validate

Spawn one validator per validation model in one batch. Agent: `rl-read-<model>`. `context`: the full text of [briefs/validate.md](briefs/validate.md), repository path, HEAD SHA, project rule files. `task`: the candidate findings with their annotations, labelled as claims. Run Consensus. Update each finding's status from the verdicts.

**Done:** every candidate has one agreed verdict, or the user answered for it. `git status --porcelain` in the main checkout equals its state before the stage. If no finding is `confirmed` or `needs-decision`, go to step 8.

## 5. Decide

- `confirmed` with a mechanical fix -> `approved`. No question.
- `confirmed` with a design choice, and every `needs-decision` -> decide one finding at a time:
  - **Human mode:** `ask` with the options that the validators gave, plus `Ignore` and `Explain more`. For `Explain more`, show code evidence, consequences, and trade-offs, then ask again. Then ask for the reason, see Reasons.
  - **Auto mode:** spawn one judge per judge model in one batch. Agent: `rl-read-<model>`. `context`: the full text of [briefs/judge.md](briefs/judge.md), project rule files, and the ledger Decisions section. `task`: the findings with their options. Run Consensus. A judge `ESCALATE` goes to the user like a split. Check `git status --porcelain` in the main checkout is unchanged afterwards.
- Record each decision and reason in the ledger.

**Done:** every `confirmed` and `needs-decision` finding is `approved`, `ignored`, or `unresolved`, with a reason.

## 6. Fix

Group `approved` findings that share an owner and a solution. Process the groups one after another:

1. For each fix model, create a worktree from HEAD: `git worktree add -b rl/r<N>-g<G>-<model> /tmp/review-loop/<repo>-r<N>-g<G>-<model> HEAD`.
1. Spawn one fixer per fix model in one batch. Agent: `rl-fix-<model>`. `context`: the full text of [briefs/fix.md](briefs/fix.md), project rule files, the main checkout path. `task`: that fixer's worktree path and branch, and the findings with evidence, acceptance criteria, annotations, and recorded reasons. Every fixer gets the same findings.
1. Check that `git status --porcelain` in the main checkout is unchanged. If a fixer changed it, stop the wave, show the user the changed files, and ask how to proceed. Check that each worktree branch has exactly one new commit.
1. One fix model -> take its commit. Two or more -> run Consensus on which commit to take or how to combine them.
1. Apply it in the main checkout with `git cherry-pick`, or combine the changes and commit them yourself. Commit subject only, Conventional Commits. Local commit only.
1. Run the affected tests and lint in the main checkout. On failure, send the failure to the chosen fixer once. If it still fails, ask the user.
1. Remove the worktrees and the `rl/r<N>-*` branches. Set the findings to `fixed` with the commit SHA.

**Done:** every approved finding is `fixed` with a commit, or `unresolved` with a reason that the user saw.

## 7. Repeat

Start step 2 with round N+1. After 5 rounds, `ask` before you start up to 5 more.

## 8. Squash and final review

Read [finish.md](finish.md) and follow it.

## Stop

Remove the push guard marker: `rm -f ~/.omp/agent/review-loop.active`. On a blocker, stop with the exact blocker, the round, the HEAD SHA, and `git status`. A failed child never counts as a clean result.

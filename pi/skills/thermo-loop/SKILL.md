---
name: thermo-loop
description: Repeat independent quality reviews with human-selected fixes and fresh-context verification.
disable-model-invocation: true
---

# Thermo Loop

Usage: `/skill:thermo-loop changes on current branch`, or supply another review scope.

The main session owns scope, decisions, and completion. Invocation authorizes native Pi subagents for review, approved fixes, and verification. Every child starts with explicit fresh context. Reviewers and verifiers are read-only. Each child receives only its stage instructions, not this whole loop.

## 1. Establish the review contract

Read the installed `pi-subagents` skill and its execution guidance before dispatch. Discover executable native Pi agents with suitable tool boundaries. At each approval boundary, return findings to the main session and use `ask_user_question`. Wait for the user's answer before dispatching approved work. If the question tool is unavailable, pause rather than substituting automatic approval.

Use [Thermo-Nuclear Code Quality Review](../thermo-nuclear-code-quality-review/SKILL.md) as the review criteria. Supply that file explicitly to review children as reference material. Its suggestions confer no edit authority.

Resolve the requested scope. For current-branch changes, identify the intended target branch, pin its merge-base commit, and include staged, unstaged, and relevant untracked changes. Ask if the target is ambiguous. Keep this comparison base fixed across rounds. Inspect related code as needed without expanding edit authority.

Record the starting repository state and applicable project instructions. Keep one writer active per checkout. Preserve unrelated changes and leave commits, pushes, and activation to separate user authorization.

**Ready:** repository, scope, comparison base, agent roles, and approval boundaries are known.

## 2. Keep the decision record

Keep reports and a compact decision record outside the reviewed source tree. Retain their locations in the main session so the loop can recover after context compaction.

For each finding record its stable ID, underlying problem, affected scope, evidence, acceptance criteria, user decision, and fix/verification results. Use these states: undecided, approved, ignored, fixing, verified.

Match repeats by underlying problem and scope, not wording or line numbers. Ignore matches only when the user marked that problem ignored during this invocation. A materially changed failure or scope is a new finding. Explain the difference, and ask when the match is uncertain. A previously verified problem that recurs needs attention, not suppression.

## 3. Review independently

Start a new read-only reviewer with the review criteria, contract, applicable instructions, and current code. Exclude previous reports, user decisions, and fix narratives from its handoff. Start a new session rather than resuming a previous reviewer.

Require findings with locations, concrete evidence, impact, a simpler direction, and checkable acceptance criteria. Require explicit coverage, limitations, and completion status. A failed or incomplete review is blocked, never an empty successful report.

**Done:** the report covers the agreed scope on a recorded code state. If that state changes during review, reassess affected coverage before using the report.

## 4. Obtain decisions

Compare findings with the decision record. Suppress ignored repeats and report their count. Present remaining findings with stable IDs and brief explanations.

Use `ask_user_question`, in supported batches, to offer Fix, Ignore for this invocation, or Explain/investigate. Explain unclear findings with code evidence, consequences, and trade-offs, then ask again. An unanswered or cancelled question leaves the finding undecided.

For a multi-selection list, confirm explicitly that unselected findings should be ignored before recording that decision. Approval applies to the problem and its acceptance criteria, not arbitrary changes suggested by a reviewer.

**Done:** each presented finding has an explicit fix or ignore decision. Pending decisions prevent completion.

## 5. Fix and verify

When fixes are approved, read [Fix and verify](references/fix-and-verify.md). Dispatch new fresh-context writers and independent verifiers using that contract. Group findings that share an owner and solution, and process separate groups sequentially.

Retry only REWORK results automatically within the original approval. Pause for user guidance after the initial fix and one retry both return REWORK for the same finding. For BLOCKED, report the blocker and use `ask_user_question` to request the missing information or authorization before proceeding. Broader scope or changed acceptance criteria requires new approval. New unrelated findings return to step 4.

**Done:** every approved finding has a verified result for the current code. Later edits invalidate results they affect.

## 6. Repeat or finish

After verified fixes, return to step 3 with another fresh reviewer. After five full reviews, ask before starting the next group of up to five rounds.

A completed review with no non-ignored findings, no pending decisions, and no unresolved validation or verification failures is **Clean under your selections**. If the user ignores all remaining findings and code is unchanged, another review is unnecessary.

Report scope, base, rounds, verified fixes, ignored findings, and validation limits. Distinguish an agreed skipped check from a required check that failed or could not run.

On an execution failure, stop with the exact blocker, run identity, and repository state. Follow the installed runner's recovery rules. A failed run cannot satisfy a completion criterion.

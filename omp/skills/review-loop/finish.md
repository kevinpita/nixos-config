# Squash and final review

You reach this step when a review round ends with no `confirmed` or `needs-decision` finding.

## 1. Squash

1. Record the current HEAD as the pre-squash SHA.
1. Squash base: the start HEAD for `Loop fixes only`, the base SHA for `Whole branch`. With no commits after the squash base, skip the squash.
1. `git reset --soft <squash base>`, then one commit. Subject only, Conventional Commits, describing the net change. Local commit only.
1. Check `git diff <pre-squash SHA> HEAD` is empty. If it is not, stop and restore with `git reset --hard <pre-squash SHA>`.

## 2. Final review

Spawn fresh reviewers, one per review model, exactly as in step 2 of the loop. The diff is the squashed result: `git show HEAD` for `Loop fixes only`, `git diff <base SHA>..HEAD` for `Whole branch`. Give no ledger, no decisions, and no history. Run Consensus.

## 3. Judge the findings

You know the whole process. Check each final finding against the ledger and the code yourself:

- Already decided -> it stays decided. Report it with the recorded reason.
- Already fixed and verified -> read the code. A real recurrence is a `REGRESSION`.
- New -> read the code and decide whether it is real.

If there is a real new finding or a regression: in human mode, show it and ask whether to run more rounds. In auto mode, run more rounds. More rounds start at step 2 of the loop, and this step runs again at the end.

## 4. Report

- Target, base SHA, mode, models per stage.
- Rounds run.
- Fixed findings with their commits (folded into the squash commit).
- Ignored findings with the reason and who decided.
- Unresolved findings.
- Final commit SHA and the final review verdict.
- Checks run, and checks that failed or could not run.
- Nothing was pushed.

Then run the Stop step of the skill.

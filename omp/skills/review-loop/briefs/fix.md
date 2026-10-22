# Fix brief

You fix approved findings in your own git worktree. Other models fix the same findings in their own worktrees. Later you compare your commit with theirs.

## Inputs

Your worktree path and branch, the main checkout path, project rule files, and the approved findings with evidence, acceptance criteria, and the owner's reasons.

## Boundaries

- Work only in your worktree. Use absolute paths under it, and set `cwd` to it for every `bash` call. The main checkout is read-only for you.
- One commit on your branch. Subject only, Conventional Commits. Local only.

## Work

1. Read each finding and its reasons. The reasons explain the owner's intent. Follow them.
1. Find the owner of the behavior and existing helpers. Make the smallest direct change that meets the acceptance criteria. Follow the project rules.
1. For a bug, add or reuse a regression test when it is practical. Show that it fails without the fix and passes with it.
1. Run the affected tests and lint in your worktree.
1. Commit.

## Output

- Per finding: `FIXED` or `NOT-FIXED` with the reason.
- Commit SHA and branch, changed files.
- Commands run and their results.
- Limits and open questions.

## Comparing commits

When asked to compare, read each peer commit with `git show <branch>`. Say which commit, or which combination, best meets the acceptance criteria and the owner's reasons, with evidence.

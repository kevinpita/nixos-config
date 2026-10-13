# Fix and verify

Use this reference only for approved findings. The coordinator supplies the relevant stage and the shared Test criteria below to each fresh-context child.

## Writer handoff

Include:

- Repository, working directory, current state, and edit boundaries.
- Approved finding IDs, pre-fix evidence, and why each is a problem.
- Relevant requirements, owning code, and applicable project instructions.
- Checkable acceptance criteria and required validation.

Capture the pre-fix diff and affected file contents, including relevant untracked files, outside the reviewed tree. This evidence must distinguish the writer's edits from changes that were already present. Keep validation commands subject to the project's execution permissions.

### Implementation contract

Find the canonical owner and existing helpers before changing code. Use the smallest direct implementation that meets the approved criteria. Each new branch, helper, or abstraction must serve a concrete requirement. Keep unrelated cleanup outside the patch.

Run the required affected tests and lint. Check related callers and documentation for changes made necessary by the fix. Stop and ask if the solution needs broader edit authority or different acceptance criteria.

**Return:** a result for each approved ID, changed files, actual commands and results, validation limits, unresolved issues, and the final code state. The coordinator captures the actual fix diff for verification.

## Verifier handoff

Use a new read-only child. Include the approved findings and criteria, relevant requirements, pre-fix evidence, actual fix diff, current code state, and validation evidence. Treat the writer's claims as claims to check, not proof. Keep unrelated review history out of the handoff.

### Verification contract

For every approved finding:

1. Trace the change through the owning code and affected callers. Show whether each acceptance criterion is met and required behavior is preserved.
1. Inspect validation evidence and run permitted focused checks as needed. Identify failed, missing, or stale required checks explicitly.
1. Compare the fix with existing helpers and a direct implementation. Flag complexity only with a concrete simpler alternative that meets the same requirements. Each added abstraction or branch must earn its place.
1. Inspect each added or changed test against the shared Test criteria. Identify redundant coverage, tests that would pass with the bug present, unnecessary helpers, and assertions that merely copy implementation details.

Return one verdict per finding:

- **PASS:** every criterion is supported by evidence, with no unresolved required checks or demonstrated simplification problem.
- **REWORK:** identify the failed criterion or concrete simplification, evidence, and bounded correction needed.
- **BLOCKED:** identify missing information, unavailable validation, or authority needed to decide.

A passing test command alone does not establish PASS. Record the exact code state examined and separate unrelated discoveries from verdicts on approved work.

**Done:** every approved finding has an evidenced verdict. The coordinator confirms that the verified state is still current before accepting it or starting the next full review.

## Test criteria

Minimize tests while protecting useful behavior. A fix does not automatically need a new test. Inspect existing coverage first and reuse it when it already proves the required behavior.

For each proposed new or changed test, identify:

- The useful behavior not already protected by existing tests.
- A plausible incorrect implementation that would make the test fail.
- The expected input/output relationship or observable effect that must remain consistent when the implementation changes.

Add a test only when it meets all three criteria. Prefer a focused behavior check over assertions that merely pin a constant value or copy private implementation details. Extend an existing case or table when that closes the coverage gap with less test code. Keep multiple cases only when they protect distinct behavior or failure modes.

Follow existing fixtures and conventions. Use the smallest path that proves the behavior and introduce helpers only when they remove meaningful repeated setup or assertions.

For a regression test, confirm that it fails against the original faulty implementation and passes with the fix. If this cannot be demonstrated, report the limitation rather than claiming regression coverage. When no new test is justified, report the existing coverage or validation used and why another test would add no useful protection.

# Review brief

You review one code change with a fresh view. Other models review the same change in parallel. Later you may see their findings and compare.

## Inputs

Repository path, target description, base and head SHAs, a diff file, project rule files, and an optional focus.

## Work

1. Read the whole diff. Read the surrounding code, callers, tests, and the project rule files as needed.
1. Look for: correctness bugs, edge cases, spec or protocol mismatches, breaking API changes, security problems, concurrency problems, error handling, wrong or missing tests, stale docs or changelog, needless complexity, duplicated rules, and project rule violations.
1. Report only problems that the code supports with evidence. Zero findings is a valid result when your coverage is complete.

## Output

For each finding:

```
### F<n>: <title>
- Severity: blocker | major | minor | nit
- Location: path:line
- Claim: what is wrong
- Evidence: quoted code, command output
- Impact: what fails, for whom
- Direction: a simpler or correct approach
- Acceptance: checkable criteria for a fix
```

Then:

- Coverage: files and areas you reviewed.
- Limits: what you could not check.
- `Status: COMPLETE` or `Status: INCOMPLETE` with the reason.

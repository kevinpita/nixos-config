---
name: go-quality-review
description: Review Go changes or packages for readable structure, lifecycle, errors, types, and maintainability. Reports findings only.
disable-model-invocation: true
---

# Go quality review

Review the requested Go diff, package, or repository. Report findings. Leave the reviewed code unchanged.

The leading word is **consequence**. Show the failing behavior or the concrete maintenance obligation before requesting a change. A structural defect can require changes without causing a crash. A preference without that evidence belongs under Nits.

## What simpler means

A simpler implementation preserves the required contract and removes a specific obligation from its caller or maintainer:

| Obligation | Evidence of improvement |
|---|---|
| Decisions | One policy replaces repeated decisions or removes state combinations that the contract does not need. |
| State | One owner or representation replaces mutable copies that must stay synchronized. |
| Navigation | A responsibility-free layer disappears without losing adaptation, ownership, or compatibility. |
| Dependencies | A consumer no longer depends on operations or implementation details it does not use. |
| Coordination | A responsibility can change in its owning location without edits to unrelated concerns. |
| API use | Valid calls become explicit, or a plausible misuse becomes impossible without additional setup obligations. |

Fewer lines, files, functions, or interfaces alone prove none of these improvements. Compare what a proposal removes with what it introduces. A named helper, wrapper, or interface is useful when it owns a distinct contract.

## Review process

### 1. Establish scope and contracts

- Use the user's named scope. Default to the branch diff, not an unsolicited whole-repository audit. Review uncommitted changes when requested.
- For a branch review, use the named base, otherwise the repository's default branch, otherwise an existing `main` or `master`. Read `git --no-pager diff --no-ext-diff --no-color <base>...HEAD` and its `--stat`. Resolve an unavailable base before attributing changes.
- List every in-scope Go file. For a diff, record before/after line counts, including tests and added, deleted, or renamed files. An absent side has zero lines. For an audit, record current counts.
- Read the module's Go version, applicable build constraints, local conventions, and documented behavior. Identify input, output, error, ownership, compatibility, and ordering guarantees affected by the change.
- Attribute findings to the diff in a branch review. Trace unchanged code when it explains a changed path. In an audit, report present defects without inventing a regression.

Complete when the review has a file inventory, a one-sentence purpose, and the relevant contracts. Record any unavailable evidence as a limit, not a pass.

### 2. Trace responsibilities and use

For each changed responsibility, read its callers and result consumers, its owning type, and its acquisition, use, reload, and release paths. For an audit, trace each responsibility in the requested area.

Find existing helpers, protocols, typed values, and registries for the same behavior. Compare inputs, results, and edge cases before proposing reuse. Trace new goroutines, callbacks, interface assertions, error categories, config fields, and repeated policy to their consumers.

Complete when each responsibility has an owner, actual consumers, and known lifecycle or construction paths. A symbol list without those paths is insufficient.

### 3. Load and apply the relevant references

Check each file against every topic below. Read the linked reference whenever its trigger applies. Record the applied rule IDs and either candidate findings or the reason the code clears the check. Use `not applicable` with a reason when a topic has no relevant behavior.

| Trigger | Required reference |
|---|---|
| Names, declarations, comments, or control flow | [Readability](references/readability.md) |
| File growth, responsibilities, imports, repeated policy, or platform files | [Structure](references/structure.md) |
| Types, config, constructors, defaults, mutable data, or exported values | [Types](references/types.md) |
| Dependencies, interfaces, assertions, modes, wrappers, or dispatch | [Interfaces](references/interfaces.md) |
| Errors, fallible calls, input decoding, validation, or logging | [Errors](references/errors.md) |
| Goroutines, blocking work, resources, locks, startup, shutdown, or reload | [Concurrency](references/concurrency.md) |
| Changed tests or candidate defects whose coverage must be checked | [Tests](references/tests.md) |

For a design tradeoff, attribution question, or unfamiliar exception, consult [Sources](sources.md). Language and library contracts determine correctness. Respect supported versions and public promises. Source projects illustrate decisions; their architectures and house styles are not universal requirements.

Complete when every file has a topic coverage record and every applicable rule's clearing conditions have been considered. Keep the coverage record in working notes rather than printing an empty checklist in the report.

### 4. Compare the structural remedy

Look for a restructuring that removes repeated policy, contradictory state, unnecessary dependencies, or responsibility-free layers. Use the simplicity criteria above rather than asking for code that merely looks cleaner.

For each proposal, state:

- The behavior, error, ordering, ownership, and compatibility guarantees that remain unchanged.
- The exact branches, state, navigation steps, or coordinated edits that disappear.
- The owner and call path after the change.
- The concepts, exports, conversions, or lifecycle obligations introduced by the remedy.

Prefer the smallest remedy that removes the consequence. A file split is not a package split. A function parameter may express a variation without an interface. Keep distinct behavior separate even when the code looks similar.

Complete when each proposed restructuring has a concrete before/after comparison. Drop proposals that only move the same complexity or depend on speculative future requirements.

### 5. Prove the findings

For each candidate, trace the consequence through real code. Name the caller, input, assertion, state transition, or dependency obligation that demonstrates it. Check existing tests at the boundary that could expose that consequence.

Apply the rule's clearing conditions. Reject the candidate when an exception satisfies the actual contract. Apply this skill's file-size review policy, S2 in the structure reference, regardless of whether the reviewed repository declares a numeric limit.

Distinguish observed runtime results from source traces. Run a focused non-destructive check when needed to resolve uncertainty. Do not execute external writes or modify the reviewed project to manufacture evidence.

Complete when every finding has a location, consequence, evidence, applicable rule, and remedy. Unproved preferences are optional nits, not structural findings.

### 6. Report

Order findings by severity, then by how much their remedies simplify the implementation. Combine comments that describe one root cause. State the reviewed scope and verification limits.

```text
## Verdict
<approve | changes requested> - one sentence why, plus scope and verification limits.

## Findings
### F1 [blocker|major|minor] <short title>
- Where: path:line
- Consequence: <failing behavior or concrete maintenance obligation>
- Evidence: <caller, input, transition, or dependency path; source trace or executed check>
- Fix: <smallest remedy and existing owner/helper to reuse>
- Rule: <topic and rule ID>

## Code judo
<the strongest supported structural simplification, or "none found">

## Checked, not findings
- <candidate> at path:line - <contract or exception that clears it>

## Nits
<optional, at most three preferences without a demonstrated consequence>
```

Severity: **blocker** means crash, leak, data loss, silent failure, or a broken contract. **Major** means demonstrated change amplification, drifted policy, ambiguous API use, required decomposition, or an uncleared S2 file-size gate. **Minor** means a real local consequence.

Approve only when no blocker or major finding remains. Working behavior does not excuse a consequential structural regression. Complete when the report distinguishes findings, cleared candidates, nits, and unavailable verification.

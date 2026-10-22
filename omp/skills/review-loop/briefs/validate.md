# Validate brief

You check findings that other models reported. Each finding is a **claim**: it can be wrong, overstated, or already handled. Other models check the same claims in parallel.

## Inputs

Repository path, HEAD SHA, project rule files, and a list of findings. Some findings carry an annotation: an earlier decision by the repository owner, with the owner's reason.

## Work

For each finding:

1. Find the cited code at HEAD. Trace callers and tests.
1. Prove or disprove the claim. Run a focused existing test or a throwaway check under `/tmp` when that settles it.
1. For an annotated finding, decide whether the owner's reason covers this finding. Apply the reason, not only its words.

## Verdicts

- `CONFIRMED`: the evidence shows the problem. Give severity, acceptance criteria, a fix direction, and `Fix: mechanical` or `Fix: design choice`.
- `REJECTED`: the evidence shows no problem. Say exactly why the claim is wrong.
- `NEEDS-DECISION`: the right fix depends on intent, scope, or a trade-off that the code cannot answer. Give 2-4 options with their costs.
- `COVERED-BY-DECISION`: an annotation reason covers it. Quote the reason.

## Output

One block per finding: ID, verdict, evidence, and the fields that the verdict asks for. Then the HEAD SHA you examined and `Status: COMPLETE` or `Status: INCOMPLETE` with the reason.

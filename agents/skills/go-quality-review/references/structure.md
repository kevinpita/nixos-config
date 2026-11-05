# Structure

## S1. Split responsibilities, not declarations

- Check what each file and package owns, its callers, imports, shared state, and reasons to change. Name the independent responsibilities before proposing a split.
- Finding: a new concern makes an unrelated owner know feature details, or a contributor must edit unrelated concerns to change one behavior. Show those locations and the boundary that removes the obligation.
- Clear: several related types can form one concern. A small command can keep options, construction, execution, and a local helper together. A new file per type can scatter the same operation without removing coupling.
- First consider a same-package file named for the concern, such as `reload.go` or `codec.go`. Create a package only when a real import, reuse, or visibility boundary justifies its API and dependency costs. Keep private same-package helpers local. `internal/` restricts package imports; it is not a destination for every unexported function.

A file split changes navigation. A package split can force new exports or conversion APIs. Account for those costs and preserve initialization order and build constraints.

## S2. Apply the 1000-line review gate

This is the skill's explicit strict review policy, not a Go language rule.

- Check the recorded before/after counts for every changed Go file. If a file grows from under 1000 lines to over 1000, require a decomposition assessment before approval.
- Finding: report a major finding when that crossing is not justified by one cohesive type or concern. Identify the responsibilities mixed together and propose their owning files. An unexplained claim that the file is cohesive does not clear the gate.
- Clear: the resulting file still expresses one cohesive type or concern, and splitting would scatter its contract or state machine rather than separate independently understandable behavior. Explain that relationship explicitly.
- Decompose by responsibility, not equal-sized chunks. Generated output needs a remedy in its owning generator when appropriate, not hand edits that regeneration discards.

Files already over the threshold and files below it still receive S1's responsibility check. In a package or repository audit, inspect current cohesion without inventing a before/after crossing. File counts are evidence for this policy, not a general complexity score.

## S3. Give shared policy one owner

- Check repeated blocks for the same intention, inputs, outputs, error precedence, and edge cases. Follow every relevant caller before deciding that the blocks implement one policy.
- Finding: show matching policy copied across locations that already disagree, or require the same rule to be changed in multiple independently maintained places. Identify the actual shared contract, not just similar syntax.
- Clear: the blocks have different stopping conditions, ownership, validation boundaries, or error behavior. Short local operations and tests with different checking logic can remain separate when extraction would require mode flags or obscure their differences.
- Reuse the existing owner where it fits. Otherwise extract the shared policy at the lowest existing layer that has its required knowledge. A new package needs S1's justification. Generics help only when operations and contracts match and types are the remaining variation.

For example, two adapters using the same retry eligibility rule should call one policy. Two loops with different delivery and acknowledgment guarantees should not be merged merely because both retry.

## S4. Keep feature knowledge at its owning boundary

- Check new imports and where implementations are selected. Follow any existing plugin, factory, or registry boundary through registration, lookup, and consumption.
- Finding: show an import cycle, a core package that must change for each new plugin despite its existing registration contract, or an unrelated consumer coupled to a backend detail. Name the dependency that causes the obligation.
- Clear: an executable or composition package can import and wire features. A concrete dependency is appropriate for a small program when an abstraction removes no real obligation. Shared protocol packages can own coherent contracts.
- Move feature selection to the existing composition or registration point. Keep the core dependent on its actual contract. Reuse that extension point rather than add another dispatcher. For mode-specific drift, apply [Interfaces](interfaces.md).

A directory tree copied from another project does not prove dependency direction. Compare actual imports and callers.

## S5. Make supported platform boundaries explicit

- Check platform filenames, build tags, supported targets, and the declarations that common code calls. Verify that tests end in `_test.go`, such as `socket_windows_test.go`.
- Finding: a supported target cannot build because a required declaration has no implementation, platform dependencies enter a common build, or a test is compiled as production code because of its filename.
- Clear: a deliberately platform-specific package does not need a fallback for platforms it does not support. Different implementations can share a contract without identical internal structure.
- Put platform behavior in `_GOOS.go` files or appropriate build constraints. Supply matching required signatures for every supported build. Name a fallback's build constraints explicitly; `other` is not itself a GOOS suffix.

## Sources

See [official module layout](../sources.md#official-go), [Google package cohesion](../sources.md#google), and the [CLI](../sources.md#github-cli), [tools](../sources.md#go-tools), and [Tailscale](../sources.md#tailscale) reading routes. These support responsibility-based organization. They do not establish the numeric gate in S2.

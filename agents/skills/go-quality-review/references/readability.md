# Readability

## R1. Name values for the reader at the call site

- Check the package-qualified name, receiver, scope, and other values used beside it. Prefer `bufio.Reader` over a name that repeats its package. Let names become more descriptive as scope or ambiguity grows.
- Finding: show two meanings that the name fails to distinguish, a misleading effect, or an actual argument/result confusion. For example, two unnamed integer results used as width and height leave callers to reconstruct their order.
- Clear: `r`, `w`, `ctx`, `db`, short receivers, and small loop indices are clear when their meaning is established locally. A familiar abbreviation is not a defect because it is short.
- Fix the ambiguous name or name the results. Keep established initialisms and receiver names consistent. Avoid a package rename when a local name resolves the confusion.

These signatures communicate different amounts of information to a caller:

```go
func Dimensions() (int, int)
func Dimensions() (width, height int)
```

Named results explain the contract here. They do not require naked returns in the implementation. For ambiguous boolean arguments, apply [Interfaces](interfaces.md).

## R2. Put related declarations on one reading path

- Check the declarations needed to understand one operation. Follow the public entry point through its type, construction, methods, and helpers. Identify unrelated concepts that interrupt that path.
- Finding: name the operation that requires readers to reconstruct dependencies across unrelated declaration groups, and show which relocation would remove that navigation. Reordering alone is a preference unless it resolves a demonstrated discovery or misunderstanding problem.
- Clear: related types can share a file. Private helpers can follow their callers. Existing receiver grouping, call order, or API-first order can each be coherent. Go does not prescribe a universal alphabetical or exported-first order.
- For new code without a local convention, introduce the principal type and contract, construction, principal operations, then supporting details. Keep tightly related methods together. Use [Structure](structure.md) when the remedy needs a file or package boundary.

Keep import formatting under `gofmt` and the repository's import tool. A manually maintained sort scheme for all declarations adds an obligation without proving readability.

## R3. Make the normal path and state changes explicit

- Check nested success paths, fallthrough, reused variables, and hidden mutations. Trace the values the reader must remember before a branch and after it.
- Finding: show an unnecessary nesting or branch that obscures a concrete state transition, duplicates a policy decision, or makes an error path appear to be success. Explain which states disappear in the replacement.
- Clear: a short conditional or switch can be the clearest complete model. Multiple branches that express genuinely different behavior do not need a strategy hierarchy. A narrow variable scope is not worth nesting the whole success path.
- Handle exceptional paths early when their contract permits it. Keep the remaining sequence explicit. Preserve valid partial results and ordering guarantees under [Errors](errors.md).

For an operation whose result is unusable on error, this shape keeps the successful operation outside an `else`:

```go
func NormalizeAddress(raw string) (string, error) {
	addr, err := netip.ParseAddr(raw)
	if err != nil {
		return "", fmt.Errorf("parse address: %w", err)
	}
	return addr.String(), nil
}
```

This is not a rule to return before using partial bytes from `io.Reader`.

## R4. Put meaning in code and contracts in documentation

- Check what a helper name, intermediate value, or comment lets the reader understand without inspecting distant code. Compare the knowledge required before and after extraction.
- Finding: identify a concealed effect or unstated usage constraint that callers need for correct use. Also flag a comment that contradicts the implementation and directs callers toward an incorrect operation.
- Clear: a short local calculation need not become a helper. A comment explaining a protocol constraint, ownership, units, concurrency safety, or a non-obvious reason can communicate information that naming cannot replace. Public documentation is not redundant merely because the implementation is short.
- Prefer a meaningful name or explicit step for an ordinary operation. Document the remaining contract where its callers find it. Remove stale explanations made obsolete by the current change. Cosmetic wording and comment density alone are nits.

For example, a borrowed slice needs its mutation/lifetime contract documented or enforced. Adding a helper named `processData` does not establish that contract. Use [Types](types.md) for the actual aliasing check.

## Sources

See [official naming and direct flow](../sources.md#official-go), [Google's reader-first principles](../sources.md#google), and [Uber's grouping guidance](../sources.md#uber). Exact declaration order is contextual guidance, not a language requirement.

# Interfaces and dispatch

## I1. Choose the seam from a real consumer

- Check: Find who calls the dependency, which operations it needs, and what substitution or encapsulation the change requires. Look for existing function and transport seams.
- Finding: A new interface or forwarding layer hides the only implementation without a distinct contract, duplicates an existing seam, or forces consumers to depend on unrelated application machinery.
- Clear: A narrow consumer interface can hide a large concrete API even with one implementation. A real test seam can justify substitution, but does not automatically justify a second interface around an existing client.
- Fix: Use a concrete value for direct behavior, a function for one operation, or a small interface for a behavioral protocol. Reuse an existing seam before inventing another.

A clock dependency can be `now func() time.Time`. An HTTP client can often stay `*http.Client` and use its existing `http.RoundTripper` seam.

## I2. Keep interfaces small without fragmenting protocols

- Check: Compare each interface method with real consumer calls and shared behavioral obligations. Inspect implementation stubs and the effects of adding a method.
- Finding: Implementers must supply irrelevant methods, or a consumer change breaks unrelated implementations because the contract combines independent responsibilities.
- Clear: Coupled protocols such as `io.ReadWriteCloser` or a meaningful paired lifecycle belong together. Shared protocol ownership and generated schema interfaces need not move into every consumer package.
- Fix: Define the needed contract near its consumer by default. Reuse coherent shared protocols. Split unrelated capabilities rather than mechanically reducing method counts.

Return concrete types by default. Returning an interface is appropriate when it is the complete public contract of a private implementation, as with hash constructors, or selects genuinely interchangeable implementations. Count the encapsulation benefit against hidden useful methods and navigation cost.

## I3. Make optional dispatch and promised conformance explicit

- Check: Locate runtime assertions and registries, the exact dynamic type including pointer versus value, and the documented capabilities of each implementation.
- Finding: Show an actual method-set mismatch that skips promised behavior, an unchecked assertion on a reachable unsupported value, or a promised runtime-only implementation contract lacking a static check.
- Clear: A normal typed argument, assignment, or return already checks conformance. Optional discovery alone does not mean every encountered type promises the capability. A mandatory plugin assertion can enforce a documented programmer contract.
- Fix: Check optional behavior with a comma-ok assertion at its dispatch owner. Add `var _ I = (*T)(nil)` only for the intended implementation and exact interface that need protection.

A missing guard is not a finding merely because a future signature might drift. Identify the explicit implementation promise and runtime-only dispatch, or show the actual mismatch.

In this example, construction supplies a non-nil writer, and the host discovers `flusher` only at runtime. `bufferedSink` promises that capability. Flushing does not close the writer or transfer ownership.

```go
type flusher interface {
	Flush() error
}

type bufferedSink struct {
	writer *bufio.Writer
}

func (s *bufferedSink) Flush() error {
	return s.writer.Flush()
}

var _ flusher = (*bufferedSink)(nil)

func flushOptional(v interface{}) error {
	if f, ok := v.(flusher); ok {
		return f.Flush()
	}
	return nil
}
```

The assertion must match the dispatched signature. `Flush()` and `Flush() error` describe different capabilities, and a value may lack its pointer type's methods.

## I4. Keep fixed modes direct and consolidate drifted dispatch

- Check: Trace the same mode across selection, defaults, execution, and cleanup. Search for the existing strategy, constructor table, or registry before adding another switch.
- Finding: Equivalent switches already disagree, a new variant requires coordinated edits across unrelated flows, or parallel dispatch bypasses the repository's established extension contract.
- Clear: One switch over a closed, fixed set is often the clearest code. Translating configuration names to values is not automatically an interchangeable algorithm family.
- Fix: Select behavior once where the variation actually begins. Reuse the existing registry or protocol when present. Use functions or a small strategy interface only when they remove repeated policy and preserve the contract.

An open plugin registry earns registration machinery. A closed set can remain a direct switch or static constructor map. A hypothetical future third mode does not justify either abstraction.

## I5. Name behavioral choices at call sites

- Check: Read calls without jumping to the signature. Distinguish domain facts from flags that select unrelated behavior, especially consecutive positional booleans.
- Finding: Calls such as `Load(path, true, false)` conceal which behavior the caller requests, or boolean combinations expose unsupported states that callers must reconstruct.
- Clear: A single obvious boolean, a named local value, or a call whose surrounding code states the meaning can be readable. A boolean data property is not automatically a mode.
- Fix: Use named operations for distinct actions, a typed mode for mutually exclusive choices, or an options value for independent settings. Avoid functional-option machinery for a small fixed internal call.

For independent settings, this complete type makes `LoadOptions{Strict: true, FollowLinks: false}` readable at the call site.

```go
type LoadOptions struct {
	Strict      bool
	FollowLinks bool
}
```

Check option defaults and presence with [Types and configuration](types.md#t4-resolve-defaults-without-losing-presence).

## I6. Keep adapters that preserve a useful contract

- Check: Compare behavior before and after a wrapper, including ownership, errors, defaults, public methods, and optional dispatch such as `io.WriterTo` or `io.ReaderFrom`.
- Finding: A pass-through layer adds navigation with no distinct responsibility, or an adapter loses a capability the actual caller relies on. Forwarding a fast path can also bypass counting, limits, or inspection.
- Clear: A small adapter can limit exported methods, translate protocols, preserve buffered bytes, or centralize real policy. An optional fast path need not be preserved when it violates the wrapper's semantics.
- Fix: Delete only responsibility-free layers. Preserve the capabilities the wrapper promises, through explicit methods or the protocol's supported unwrapping mechanism. Keep required interception on every enabled path.

`io.NopCloser` preserves `io.WriterTo` when available. `http.ResponseController` can reach supported operations through `Unwrap`. Neither pattern grants every wrapper an obligation to expose every underlying method.

## I7. Compose chains only to remove scattered policy

- Check: Follow optional steps, ordering, short-circuit behavior, error handling, and the terminal operation. Compare a composed chain with the existing direct flow.
- Finding: The same optional policy is scattered across handlers or repeated central branches, and composition removes those repeated decisions without hiding required order or cleanup.
- Clear: A short fixed sequence of conditions can be clearer than a chain. A chain adds cost when each step forces readers to reconstruct order or shared mutable state.
- Fix: Compose existing handler or function contracts at setup when that consolidates actual policy. Keep the real terminal operation explicit. Preserve cancellation, errors, ownership, and optional capabilities that the consumer uses.

This middleware adds a response header before the real handler. Its precondition is a non-nil `next`. It owns no resources and does not wrap or narrow `ResponseWriter` capabilities.

```go
func withNoCache(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}
```

Use this composition when several routes need that same policy. A single local header assignment does not require middleware or a synthetic no-op terminal handler.

## Sources

See [official interface guidance](../sources.md#official-go), [standard-library capability dispatch](../sources.md#go-standard-library), [Caddy's optional hooks](../sources.md#caddy), and [tools' function-based contracts](../sources.md#go-tools).

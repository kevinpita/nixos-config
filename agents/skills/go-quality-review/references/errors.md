# Errors and input boundaries

## E1. Preserve the promised error contract

- Check callers and documentation for `errors.Is`, `errors.As`, predicates, exact identity, cancellation, and EOF behavior. Follow causes through wrappers, adapters, and translations.
- Finding: formatting with `%v`, replacing an error, or wrapping a direct sentinel breaks a promised caller branch. Exposing a dependency cause can also create an unintended public compatibility obligation.
- Clear: `%v` can intentionally hide an implementation error at an abstraction boundary, not only at a printing boundary. A nil-or-non-nil contract need not expose internal causes.
- Fix: use `%w` when inspectability is part of the contract. Translate implementation failures into the promised domain condition when that is the boundary's job. Preserve useful operation context without adding an accidental cause contract.
- Preserve direct `io.EOF` where the protocol requires it. `io.Reader` implementations return EOF itself, not an error wrapping EOF, because consumers can compare it with `==`. An exact comparison is not automatically a nit when identity is promised.

## E2. Classify errors by caller needs

- Check which distinctions callers consume and whether they need identity, category, associated data, or a stable predicate across implementations.
- Finding: a fresh error is compared with a separately allocated error, a caller matches unstable text, or a translation loses fields needed for recovery. Rewrapping a typed error can accidentally overwrite its original status or location.
- Clear: a package-level sentinel suits a fixed data-free condition. Typed errors, custom `Is` or `As` behavior, documented protocol categories, and predicate functions are equally valid when they match caller needs. Diagnostic-only errors need no invented sentinel.
- Fix: reuse the existing classification API. Allocate identity sentinels once and use `errors.Is` where wrapping is allowed. Use `errors.As` or a predicate for typed data. Retain established metadata when adding outer context.

Preconditions: callers classify this package's limit failures by type or `IsLimit`. The type intentionally exposes the value and bound. Its methods require a non-nil receiver. These definitions use `errors` and `fmt`.

```go
type LimitError struct {
	Value int
	Max   int
}

func (e *LimitError) Error() string {
	return fmt.Sprintf("limit %d is outside 1..%d", e.Value, e.Max)
}

func IsLimit(err error) bool {
	var target *LimitError
	return errors.As(err, &target)
}
```

A typed wrapper adds `Unwrap() error` only when exposing its cause is intentional under E1. A classification type need not contain a cause.

## E3. Preserve partial results and error precedence

- Check every multi-result API for useful results on failure. Trace bytes, counts, iterators, pages, and partially acquired resources before choosing an early return.
- Finding: a caller discards `n > 0` bytes because Read also returned an error, treats a short write as success, or consumes a result that the producer declares invalid on error.
- Clear: ordinary constructors often promise no usable result on failure. Stream protocols can promise both data and an error. Follow that specific contract rather than applying one return order everywhere.
- Fix: consume the valid portion before handling the accompanying error. Prefer `io.Copy` when its behavior fits. Preserve EOF as normal completion only at an operation that promises that interpretation.
- Check deferred Close, flush, rollback, and cleanup errors. A successful operation can still fail to commit buffered output. A cleanup failure can also hide the primary failure if it overwrites the return error.
- Clear: documented error precedence can retain the primary error and discard an irrelevant cleanup error. Combining failures is useful only if the resulting inspection and identity behavior still matches E1.
- Fix: choose the primary outcome deliberately, report material cleanup failures through the existing error policy, and preserve every promised valid result. Resource ownership and rollback order belong in [concurrency](concurrency.md#c3-clean-partial-failures-and-roll-back-in-dependency-order).

## E4. Return a nil interface on success

- Check functions returning `error` or another interface for typed pointer variables returned on success. An interface containing a nil pointer is not a nil interface.
- Finding: a nominally successful operation returns a non-nil error interface, sends the caller down an error branch, or panics when formatting a nil receiver.
- Clear: a non-nil error interface that intentionally represents a failure is valid even if its implementation tolerates a nil receiver. That behavior does not make it a successful nil error.
- Fix: return literal `nil` on success. Convert a typed error to the interface only on its failure path. A nil-safe Error method alone does not repair the success contract.

Preconditions: `max` is a positive bound already established by the owning API. This function uses the `LimitError` above and returns an actual nil error for valid input.

```go
func validateLimit(n, max int) error {
	if n < 1 || n > max {
		return &LimitError{Value: n, Max: max}
	}
	return nil
}
```

## E5. Parse and validate at real trust boundaries

- Check every entry path for config, environment, flags, requests, decoded data, and independently callable APIs. Locate the invariant required by the eventual arithmetic, allocation, index, or I/O operation.
- Finding: invalid input reaches later runtime work, repeated hot-path parsing drifts, or syntactically valid values bypass a range check. Check negatives, zero semantics, upper bounds, multiplication overflow, narrowing, and relationships between fields.
- Clear: decoding each new request is a real boundary. A public API can need validation even when its usual caller validates. Trusted internal operations can rely on an established invariant. A named type alone does not establish validity; see [types](types.md).
- Fix: parse, apply documented defaults, and validate once per newly received input at the responsible boundary. Bound untrusted input size before expensive parsing where needed. Keep the validated value for use, without requiring a second config representation.

Preconditions: this config boundary accepts a decimal item count, charges 1024 bytes per item, and permits at most 8 MiB. It intentionally exposes `strconv` syntax errors through wrapping. The bounded result fits even a 32-bit `int`.

```go
func parseBatchBytes(raw string) (int, error) {
	const itemBytes = 1024
	const maxBytes = 8 << 20
	if len(raw) > 20 {
		return 0, errors.New("batch_items is too long")
	}
	n, err := strconv.ParseUint(raw, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("batch_items: %w", err)
	}
	if n == 0 || n > maxBytes/itemBytes {
		return 0, fmt.Errorf("batch_items must be in 1..%d", maxBytes/itemBytes)
	}
	return int(n) * itemBytes, nil
}
```

## E6. Keep ordinary input failures out of panic paths

- Check whether config, request data, or recoverable operational failures can reach `panic`, a `Must` helper, or an unchecked assertion. Inspect recovery boundaries and the API's documented panic policy.
- Finding: ordinary bad input terminates a process or request worker instead of producing the promised error, or broad recovery silently turns a programmer defect into apparent success.
- Clear: programmer errors such as duplicate static registration, violated internal invariants, and Must helpers on fixed valid input can justify panic. An explicitly documented panic API needs contract review, not a mechanical conversion.
- Fix: return an ordinary error at the input boundary. Reserve recovery for an intentional isolation boundary with defined failure behavior. Match existing registration synchronization and lifecycle rules rather than introducing an unchecked global registry example.

## E7. Give each diagnostic one owner

- Check where an error is classified, returned, logged, rendered to a user, and converted to exit status. Follow the same failure across component and application boundaries.
- Finding: multiple layers print the same failure, expected cancellation becomes Error-level noise, or a dropped error loses the only actionable diagnostic.
- Clear: an application boundary may render help and return a recognized presentation-aware exit signal. Separate operational events are not duplicate diagnostics merely because they share a cause.
- Fix: return an error with useful context until the owner handles it, or log it where it is intentionally dropped. Use the repository's component-scoped logger and structured fields. Choose severity from the outcome, not merely from `err != nil`. Preserve enough context for the owner without logging secrets or duplicating its message.

## Sources

See [official error and wrapping guidance](../sources.md#official-go), [standard-library EOF and partial results](../sources.md#go-standard-library), [restic's classification and cleanup](../sources.md#restic), and [CLI error ownership](../sources.md#github-cli).

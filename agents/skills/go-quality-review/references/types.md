# Types and configuration

## T1. Carry semantic units in values

- Check: Follow durations, sizes, addresses, identifiers, and normalized strings from input to their arithmetic and call sites.
- Finding: Raw values force callers to remember units, repeat parsing, or apply conflicting normalization. Name the confused call or repeated policy.
- Clear: Plain counts and local strings need no domain wrapper when their meaning stays unambiguous. A named type adds meaning, not validation by itself.
- Fix: Use an existing repository type or a suitable standard type, such as `time.Duration` or `netip.Addr`. Convert external units once at the input boundary.

## T2. Establish invariants on every creation path

- Check: Inspect constructors, literals, public conversions, zero values, setters, and decoding methods. Find which operations assume normalized or validated values.
- Finding: An actual creation path bypasses a required invariant and reaches an operation that relies on it. A constructor alone does not protect a publicly convertible named type.
- Clear: The type deliberately permits raw values, and operations validate before relying on stronger guarantees. Trusted internal construction can carry an explicit precondition.
- Fix: Validate at the entering boundary, implement the relevant decoding contract, or restrict representation when callers need an enforced invariant. Avoid repeated checks inside already-validated operations.

Here the protocol permits ports 1 through 65535. `ParsePort` validates text, but `Port(0)` and the zero value still bypass it.

```go
type Port uint16

func ParsePort(raw string) (Port, error) {
	n, err := strconv.ParseUint(raw, 10, 16)
	if err != nil {
		return 0, fmt.Errorf("parse port %q: %w", raw, err)
	}
	if n == 0 {
		return 0, fmt.Errorf("port must be in 1..65535")
	}
	return Port(n), nil
}
```

Use the range and overflow checks in [Errors and input boundaries](errors.md) for conversions and later arithmetic.

## T3. Distinguish a useful zero from configuration defaults

- Check: Read what zero means for each type and operation. Check required dependencies, map writes, resource acquisition, and wire encoding separately.
- Finding: An advertised usable zero panics, a required invariant never gets initialized, or a constructor imposes setup with no distinct responsibility.
- Clear: A zero `sync.Mutex` is usable. Nil slices support append, and nil maps support reads. A resource-owning object or required dependency can legitimately need construction.
- Fix: Make zero work where practical, initialize maps before writes, or use a constructor to establish real invariants. Preserve zero meanings such as disabled, empty, and unlimited.

A usable zero `http.Client` has no timeout. That library contract does not establish a safe timeout for every application.

## T4. Resolve defaults without losing presence

- Check: Trace omitted, explicit zero, false, null, and inherited values through decoding, merging, and preparation. Locate the owner of each default.
- Finding: Defaulting overwrites an explicit choice, fixed and context-dependent defaults disagree across paths, or scattered nil checks expose unresolved configuration to runtime consumers.
- Clear: A plain field suffices when omission and zero mean the same thing. A pointer can preserve presence for a fixed default of true, not only a context-dependent default.
- Fix: Resolve defaults once at the appropriate preparation boundary. Use a pointer or explicit presence value only where the input contract distinguishes absence.

This resolver supports either a fixed fallback or one computed from surrounding configuration. The caller owns that choice.

```go
func resolveBool(raw *bool, fallback bool) bool {
	if raw != nil {
		return *raw
	}
	return fallback
}
```

For ordinary JSON decoding into a fresh struct, `*bool` distinguishes false from absence but treats null and absence alike. Use explicit presence tracking if the protocol distinguishes both.

## T5. Separate serialized meaning from prepared state

- Check: Trace raw strings and encoded modules into the typed state runtime code consumes. Inspect serialization tags, exported fields, and repeated preparation.
- Finding: Requests reparse static configuration, runtime-only state leaks into a wire API, or independently mutable raw and derived fields can disagree during use.
- Clear: One struct can hold exported serialized fields and private prepared fields. Directly decoded typed data or short-lived command options may already have the correct representation.
- Fix: Prepare once before use and exclude runtime-only state from serialization. Add distinct raw and runtime structs only when different shapes, ownership, or validity guarantees repay the conversion cost.

Keep the semantic boundary explicit even when it lives within one object. Reload publication and overlapping owners belong in [Concurrency and lifecycle](concurrency.md).

## T6. Keep noncopyable state with its owner

- Check: Inspect receiver choices, value parameters and returns, assignments, interface boxing, range variables, and container elements for copies of lock-bearing state.
- Finding: A copy after first use duplicates a mutex or another noncopyable synchronization value, or leaves separate locks protecting the same aliased data.
- Clear: Value semantics suit independent immutable data. A pointer receiver alone does not prevent callers from copying the containing struct. A pre-use copy must respect every contained type's contract.
- Fix: Retain one owner and pass its pointer where identity matters. Keep synchronization fields named and private. Change the specific copying path rather than converting every receiver to a pointer.

Pointer fields and embedded structs can carry ownership obligations too. Check the whole value, not only visible mutex declarations.

## T7. Define ownership of maps, slices, and nested pointers

- Check: Follow retained arguments, returned collections, subslices, append capacity, and nested mutable elements. Find who may mutate each alias and under which lock.
- Finding: A caller mutates internal state outside its lock, two owners overwrite shared storage, or a claimed snapshot still shares mutable elements.
- Clear: Borrowed read-only data, explicit ownership transfer, and deliberately shared synchronized data need no automatic copy. A shallow copy suffices for immutable elements.
- Fix: Copy at the actual ownership boundary, transfer ownership explicitly, or keep mutation behind the owner. Deep-copy only the mutable parts the contract promises to isolate.

For Go 1.21 or later, this snapshot needs only a container copy because keys and values are strings. All writes must use the same mutex, and `Labels` must not be copied after use.

```go
type Labels struct {
	mu     sync.Mutex
	values map[string]string
}

func (l *Labels) Snapshot() map[string]string {
	l.mu.Lock()
	defer l.mu.Unlock()
	return maps.Clone(l.values)
}
```

`maps.Clone` preserves a nil map and shares referenced values. `slices.Clone` is also shallow. Neither establishes ownership of nested maps, slices, or pointers.

## T8. Expose only the API callers need

- Check: Inspect new exports, embedded fields, aliases, dependency types in signatures, and the repository's existing compatibility promises.
- Finding: An unnecessary export creates a concrete compatibility obligation, or a dependency type couples callers to a replaceable implementation contrary to the package's boundary.
- Clear: Standard types and an intentional integration API can properly expose dependencies. A library built around another library need not disguise its central protocol.
- Fix: Keep package-local helpers unexported. Limit promoted methods or add a small adapter when it preserves the intended public contract. Use `internal` only for a real package import boundary.

## T9. Match standard and generic choices to supported Go versions

- Check: Read `go.mod`, file constraints, supported toolchains, and the candidate API's version. Compare bespoke helpers with existing repository and standard-library operations.
- Finding: A change breaks a supported toolchain or maintains redundant algorithms that an available operation replaces without changing semantics or ownership.
- Clear: A direct loop can be clearer than iterators. Generics help identical algorithms over different types, but add little when an ordinary interface already expresses a method call.
- Fix: Use the least mechanism that expresses the actual operation. Preserve compatibility rather than recommending the newest API or a new dependency by habit.

## Sources

See [official zero-value, module, and generics guidance](../sources.md#official-go), [standard-library contracts](../sources.md#go-standard-library), [Uber's ownership examples](../sources.md#uber), and [Caddy's config and presence examples](../sources.md#caddy).

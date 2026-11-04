# Reference patterns

Short Go reference implementations behind the lenses in [SKILL.md](SKILL.md). Use them as models for a fix. Names are illustrative; match the repo's own names and helpers.

## Lifecycle and concurrency

### Owner

The type that starts a goroutine can stop it and wait for it. Stop cancels, then waits, so nothing touches shared state after it returns.

```go
type Poller struct {
	cancel context.CancelFunc
	wg     sync.WaitGroup
}

func (p *Poller) Start(ctx context.Context) {
	ctx, p.cancel = context.WithCancel(ctx)
	p.wg.Add(1)
	go func() {
		defer p.wg.Done()
		t := time.NewTicker(time.Minute)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				p.poll(ctx)
			}
		}
	}()
}

func (p *Poller) Stop() {
	p.cancel()
	p.wg.Wait()
}
```

Counterexample: a goroutine bounded by a request context that touches nothing Stop tears down, or one deliberately detached with a comment that says why.

### Build-then-swap

Build and start the complete new state off to the side. Swap it in under a short lock. Tear down the old state only after the swap, outside the lock.

```go
func (s *Server) Reload(cfg Config) error {
	next, err := build(cfg) // old state untouched on error
	if err != nil {
		return fmt.Errorf("building config: %w", err)
	}
	if err := next.Start(); err != nil {
		next.Close()
		return fmt.Errorf("starting config: %w", err)
	}
	s.mu.Lock()
	old := s.current
	s.current = next
	s.mu.Unlock()
	old.Stop()
	return nil
}
```

Global mutable state breaks this pattern: anything set globally during `build` needs a hand-written rollback.

### Rollback and partial start

Record what started; on failure stop exactly that.

```go
var started []Component
for _, c := range components {
	if err := c.Start(); err != nil {
		for _, s := range started {
			s.Stop()
		}
		return fmt.Errorf("starting %s: %w", c.Name(), err)
	}
	started = append(started, c)
}
```

When a constructor has several side effects, use one `err` and one deferred undo:

```go
func open(cfg Config) (_ *DB, err error) {
	f, err := os.Open(cfg.Path)
	if err != nil {
		return nil, err
	}
	defer func() {
		if err != nil {
			f.Close()
		}
	}()
	...
}
```

### Phases

Setup acquires and sets defaults; validation has no side effects; Start serves; Stop and Close release. If setup or validation fails, release what setup acquired. This makes a dry-run "check config" possible without binding ports.

### Shared resources

When two owners (old and new config during a reload) share an expensive resource such as a listener, reference-count it under one key: create on first use, destroy when the last reference goes. A single owner needs only `defer Close()`.

### Once and locks

```go
func (c *Conn) Close() error {
	if !c.closed.CompareAndSwap(false, true) {
		return nil
	}
	return c.raw.Close()
}

type Registry struct {
	mu    sync.RWMutex // guards byName
	byName map[string]Entry
}
```

A comment names what each mutex guards. Critical sections only read or swap; I/O and Stop run after Unlock.

## Errors and input boundaries

### Wrap and sentinels

```go
var ErrNotFound = errors.New("not found") // created once, lowercase, no punctuation

func (s *Store) Get(id string) (Item, error) {
	...
	return Item{}, fmt.Errorf("getting item %q: %w", id, ErrNotFound)
}

if errors.Is(err, store.ErrNotFound) { // still matches through the wrap
	http.Error(w, "not found", http.StatusNotFound)
}
```

Export a sentinel only for a condition callers branch on.

### Typed error

When callers need data, use a struct error with `Unwrap`:

```go
type HTTPError struct {
	Status int
	Err    error
}

func (e *HTTPError) Error() string { return fmt.Sprintf("status %d: %v", e.Status, e.Err) }
func (e *HTTPError) Unwrap() error { return e.Err }
```

A helper that wraps an existing `*HTTPError` should fill only missing fields, so re-wrapping never loses the original status.

### Boundary

Parse, validate ranges and apply defaults once, at load or setup. Request-handling code reads the typed fields and never re-parses config.

```go
func (c *Config) setup() error {
	if c.Timeout == 0 {
		c.Timeout = 30 * time.Second
	}
	if c.Timeout < 0 {
		return fmt.Errorf("timeout must be positive, got %s", c.Timeout)
	}
	if c.MaxItems == 0 {
		c.MaxItems = defaultMaxItems
	}
	if c.MaxItems < 0 || c.MaxItems > maxItemsLimit {
		return fmt.Errorf("max_items must be in 1..%d, got %d", maxItemsLimit, c.MaxItems)
	}
	return nil
}
```

### Panic scope

```go
func Register(name string, f Factory) {
	if _, dup := factories[name]; dup {
		panic("duplicate factory: " + name) // programmer error at init
	}
	factories[name] = f
}
```

Config and request input always return an error.

### Logging

Store a component-scoped logger at setup and log with structured fields (`slog.String("addr", addr)`, `slog.Any("err", err)`). Either return an error or log it where it is dropped, not both. Per-request detail goes at Debug.

## Interfaces and dispatch

### Guards

```go
var (
	_ io.Closer = (*Pool)(nil)
	_ Flusher   = (*BufferedSink)(nil)
)
```

Needed when the only use is a runtime assertion such as `if f, ok := s.(Flusher); ok`. A wrong receiver or parameter type would compile, the assertion would return false, and the hook would never run.

### Small interfaces and optional capabilities

```go
// Defined by the consumer, with only the method it calls.
type Fetcher interface {
	Fetch(ctx context.Context, key string) ([]byte, error)
}

// Optional behaviour, detected in one place.
type Flusher interface{ Flush(ctx context.Context) error }
```

Keep types concrete until a second implementation or a test seam exists. Keep coupled methods together when one without the other is a bug (Start and Stop).

### Strategy over mode

```go
type Selector interface {
	Select(pool []*Backend) *Backend
}

func (c *Config) setup() {
	if c.Selector == nil {
		c.Selector = RandomSelector{} // chosen once, with a default
	}
}
```

The core calls `c.Selector.Select(pool)`; it never switches on a policy name. Use a name-to-constructor registry only when the set of variants is open (plugins); a closed set is a map literal or one switch in one place.

### Positional bool

```go
// Unclear: Load(path, true, false)
func Load(path string, opts LoadOptions) (*Doc, error)

type LoadOptions struct {
	Strict      bool
	FollowLinks bool
}
```

Or two named functions, or a typed enum when a third mode is likely.

### Chains

For a pipeline of optional steps, compose small handlers instead of a central function with `if cfg.X {}` blocks:

```go
type Middleware func(http.Handler) http.Handler
```

Build the chain once at setup. End it with a no-op handler so `next` is never nil.

## Types and config

### Domain types

Use `time.Duration`, `netip.Addr` or a named type with its own `UnmarshalText` for values with units or syntax. Parse once; cap input length when the parser runs on untrusted input. Plain counts stay `int`.

### Useful zero and constructors

Config fields mean "default" at zero, the doc comment states the default, and setup applies it once. When the zero value is invalid (a map or mutex inside), keep those fields unexported and require a constructor. Named variants (`NewX`, `NewEmptyX`) are clearer than a bool parameter.

### Tri-state

```go
// StrictHost defaults to true when client certificates are required.
StrictHost *bool `json:"strict_host,omitempty"`
```

Only when the default depends on context. Otherwise a plain bool.

### Raw then typed

```go
type Route struct {
	HandlersRaw []json.RawMessage `json:"handlers,omitempty"`
	handlers    []Handler         // filled once at setup
}
```

Runtime code reads only the typed field. Runtime-only state stays unexported, out of the serialized API.

## Structure and files

- **Dependency direction**: imports point from higher-level packages (`main`, handlers) to lower-level ones (domain, storage). In a plugin architecture, the core imports no plugins; plugins import the core and register, and only `main` chooses which to build in.
- **File per concern**: one major type or feature per file, named after it, with a matching `_test.go`. Shared helpers that are not public API go under `internal/`.
- **Large files**: a large file around one cohesive type is acceptable. A file that collects many independent types, or a second unrelated job, is debt; split by concern.
- **Platform files**: `foo_linux.go` with `foo_other.go` (`//go:build !linux`) that has the same signatures. Test files must end in `_test.go` (`foo_windows_test.go`).
- **Simplifications to look for**: move duplicated logic into one internal package with tests; delete config fields that nothing reads; replace repeated string concatenation with `strings.Builder`.

## Tests

- Table-driven tests with a name or index in every failure message; `t.Run` for cases you may run alone.
- Helpers take `testing.TB`, call `t.Helper()`, and return what they observed.
- Fuzz parsers of untrusted input against properties: no panic, round-trip, idempotence.
- Assert behaviour through the public entry point, not internal fields.

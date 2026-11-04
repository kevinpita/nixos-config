---
name: go-quality-review
description: Strict Go code-quality review of a branch or diff for structure, lifecycle, errors and type boundaries. Reports findings only.
disable-model-invocation: true
---

# Go Quality Review

Review a Go change for structure, lifecycle, error and type-boundary quality. The rules hold for any Go repo: library, service or CLI.

This review reports findings. It does not edit code.

The leading word is **consequence**. A finding is a defect only when you can show what goes wrong: a goroutine that leaks on every reload, a crash on bad input, a hook that silently never runs, a call site nobody can read, copies that already behave differently. A pattern without a consequence you can trace in this code is style: leave it out or put it under Nits.

## Steps

### 1. Scope the change

- Find the base: the branch the user names, else `main`/`master`, else the merge base with the default branch. Use `git --no-pager diff --no-ext-diff --no-color <base>...HEAD` and `--stat`.
- List every changed `.go` file with its line count before and after (`git show <base>:<path> | wc -l`, `wc -l <path>`).
- Done when every changed Go file is listed with both counts, and you know what the change is for in one sentence.

### 2. Read the context the diff does not show

For each changed type and function, read:

- its callers and the place its result is used,
- the owning type and its lifecycle methods (constructor, Start/Stop, Close, init/setup and teardown hooks, reload path),
- existing helpers, interfaces, registries or typed values in the repo that already do what the new code does (`grep` for the concept, not only the name).

Done when, for every new goroutine, interface, type assertion, error return, config field and duplicated-looking block, you know who owns it, who calls it, and whether the repo already has a canonical version.

### 3. Apply every lens

Walk each changed file through all six lenses in [Lenses](#lenses). For each lens, record either candidate findings or "none". Done when every changed file has an entry for every lens.

### 4. Look for the code-judo move

Ask whether a restructuring would delete whole branches, flags, copies or layers instead of patching them: an existing interface or registry the new mode should plug into, a typed value that removes repeated parsing, a build-then-swap that removes manual rollback, a split that gives the new concern its own file. Report it as a finding when the move clearly makes the change smaller or removes a defect class. One strong judo finding beats five local nits.

### 5. Prove each finding

For each candidate:

- Trace the consequence through real code: the reload loop that calls the leaking start, the caller that does `errors.Is` on the flattened error, the assertion site that silently skips the hook, the call site with `f(x, true, false)`.
- Check the "not a finding when" clause of its rule. If the counterexample applies, drop it.
- Drop or demote to Nits anything whose consequence you cannot point to in this repo.

Done when every reported finding names its consequence and the code path that shows it.

### 6. Report

Use [Report format](#report-format). Order findings by severity, then by how much the fix simplifies the code.

## Lenses

Each rule has a consequence to prove and a counterexample that clears it. [PATTERNS.md](PATTERNS.md) holds a short Go reference implementation for each rule; read the matching section when you need a model for a fix or are unsure whether a case is a counterexample.

### Lifecycle and concurrency

- **Owner**: every goroutine, ticker, listener or file has an owner that can stop it and wait for it (ctx/cancel plus `sync.WaitGroup` or done channel; `Stop`/`Close` waits, not just signals). Consequence: leaks per reload or per constructor call; work keeps touching state after Close; races in tests. Not a finding when the goroutine is bounded by a request/ctx and touches nothing that Stop tears down, or the object lives for the whole process.
- **Cancellation**: long or blocking work takes a `context.Context` and stops on `ctx.Done()`. Consequence: shutdown or caller timeouts do not stop the work. Not a finding for short CPU-bound work.
- **Build-then-swap**: a reload or reconfiguration builds the full new state off to the side, publishes it with one locked swap, then tears down the old. Consequence of in-place mutation: a failure halfway leaves a mix of old and new config with nothing to roll back to; readers see half-built state. Not a finding for a single atomic field update.
- **Rollback**: when a later step of a multi-step start fails, every step that already started is undone (track what started, or one `err` plus a deferred undo). Consequence: earlier steps keep running and holding ports after start "failed"; the retry hits "address in use". Not a finding when the process exits on that failure, or when the undo also touches steps that never started but their Stop is safe to call.
- **Phases**: constructors or setup methods acquire resources and set defaults; validation checks without side effects; Start begins serving; Stop/Close release. Consequence of serving or binding inside a constructor: you cannot validate without side effects, and a validation failure leaks what was acquired. Not a finding for small value types with no resources.
- **Once and locks**: once-only transitions use `sync.Once` or `atomic.Bool.CompareAndSwap`; a mutex names the data it guards, critical sections do no I/O or teardown. Consequence: double close panics; Stop under a lock stalls every reader. Not a finding for state confined to one goroutine.

### Errors and input boundaries

- **Wrap**: add context with `%w` where any caller may branch on the cause. Consequence of `%v`: `errors.Is/As` in a caller stops matching; show that caller or a stdlib sentinel (`fs.ErrNotExist`, `context.Canceled`) that gets lost. Not a finding at a terminal boundary that only prints the error.
- **Sentinels**: branchable conditions are package-level `var ErrX = errors.New(...)` created once; callers compare with `errors.Is`. Consequence: an error created per call, or matched by string, never compares equal. Not a finding for errors nobody inspects. An `==` comparison that still works today is a nit.
- **Boundary**: parse, validate and default input once where it enters (config load, setup, request decode) into typed fields; hot paths trust that state. Validate ranges, not only syntax: negative, zero, and values large enough to overflow the arithmetic that uses them later. Consequence: invalid config surfaces as runtime failures long after load, a crafted value bypasses a limit, the same check runs per request, or copies of the check drift. Request input is checked when the request is decoded; that per-request check is correct, not a finding.
- **No panic on input**: panic only for programmer errors at init or registration (duplicate name, malformed static table). Consequence: one bad config or request crashes the process. Not a finding for `Must*` helpers on constant input or init-time registration.
- **Log or return**: handle an error once: return it with context, or log it where it is dropped. Consequence: duplicate log lines, Error-level noise for expected conditions. Use a logger scoped to the component, with structured fields.

### Interfaces and dispatch

- **Guard**: a type meant to satisfy an interface that is only checked by a runtime type assertion or registry gets `var _ I = (*T)(nil)`. Consequence: a signature drift (pointer vs value receiver, wrong param type) compiles and the assertion silently returns false, so the hook never runs. You must show the assertion site and the mismatch, or the missing guard where drift is likely. Not a finding when the type is passed directly to a parameter of that interface type, so the compiler already checks it.
- **Small interface**: interfaces live at the consumer and hold the methods the consumer calls (often one or two). Consequence of a wide producer-side interface: every fake and implementation stubs methods nobody calls; adding a method breaks every implementer. Not a finding for inherently coupled protocols (Start+Stop, ReadWriteCloser).
- **Optional capability**: optional behavior is a separate small interface detected with `v, ok := x.(I)` in one place. Consequence of an unchecked assertion: panic; of putting optional hooks in the base interface: no-op methods everywhere.
- **Strategy over mode**: N interchangeable variants are one small interface (or a registry entry) chosen once from config with a default. Consequence of `switch mode` / bool flags growing inside a core function: every new variant edits shared code, and the switches drift apart. Point to the existing interface or registry it should plug into when there is one. Not a finding for two fixed variants in one place.
- **Positional bool**: a `bool` parameter that selects behavior makes call sites unreadable (`Load(p, true, false)`) and a third mode needs a signature change. Prefer two named functions, an options struct or a typed enum. Not a finding for a bool with one obvious meaning (`Enabled`, `force`) or a single call site that names it.
- **Direct code**: concrete types until a second implementation or a test seam exists. Consequence of a premature interface or wrapper: indirection that hides the single real implementation. Flag pass-through wrappers that add nothing.

### Types and config

- **Domain types**: values with units or syntax (durations, sizes, addresses) get one named type or stdlib type (`time.Duration`, `netip.Addr`) parsed once. Consequence of raw `int`/`string`: unit confusion at call sites (seconds vs ms), parsing repeated and diverging. Not a finding for plain counts.
- **Useful zero**: config fields mean "default" at zero, and defaults are applied once in setup. Consequence: scattered `if x == 0 { x = default }` drift apart; a missing field silently means 0 (a 0s timeout). Use a constructor with unexported fields only when the zero value is invalid (maps, mutexes).
- **Tri-state**: a pointer (`*bool`) only when "unset" must differ from false because the default depends on context. Otherwise it adds nil checks to every read.
- **Raw then typed**: serialized form (exported, tagged) is separate from the runtime form (unexported, typed), converted once. Consequence: runtime code re-parses raw data, or runtime state leaks into the JSON API.
- **API surface**: export only what callers need; shared non-public helpers go under `internal/`. Consequence: every exported name is a compatibility promise. In a library, a dependency's type in the public API ties callers to that dependency's version; flag it only when the repo hides its dependencies elsewhere or the dependency is unstable.

### Structure and files

- **1k lines**: a change that pushes a file from under 1000 lines to over 1000 is a finding unless the file stays one cohesive type or concern. Ask for decomposition first. Size alone is not the signal: a large file of one cohesive type is fine; a file that collects independent types or gains a second, unrelated responsibility is not.
- **One concern per file and package**: files split by concern and named after it; no `util`/`common`/`misc` grab-bags. Consequence: behavior is hard to find and ownership unclear.
- **One copy**: logic repeated in two or more places is extracted when the copies mean the same thing. Show the copies, and whether they already differ (that is the consequence). Not a finding when the copies only look alike but have different inputs, outputs or edge cases.
- **Dependency direction**: lower-level packages do not import higher-level ones. Consequence to show: an import cycle, or a shared package that must change for every new feature. Where the repo already has a plugin or registration boundary, new features use it instead of being imported by the core. A package that imports and composes feature packages is fine when neither consequence applies.
- **Spaghetti growth**: a new special-case `if` inside an unrelated busy flow is a design problem. Push it behind its own function, type or the existing extension point.
- **Platform code**: OS-specific code sits in `_GOOS.go` or `//go:build` files with a matching fallback that has the same signatures. Test-only files end in `_test.go` (`x_windows_test.go`, not `x_test_windows.go`).

### Tests

- Tests prove behavior through the public entry point and fail without the change. Many cases of one behavior are a table with a name or index in every failure message. Helpers call `t.Helper()`. Parsers of untrusted input get a fuzz test for invariants (no panic, round-trip). Report a test finding only when a defect above has no test that would catch it, or a test asserts internals and would pass on broken behavior.

## Report format

```
## Verdict
<approve | changes requested> - one sentence why.

## Findings
### F1 [blocker|major|minor] <short title>
- Where: path:line
- Consequence: <what goes wrong, concretely>
- Evidence: <the code path that shows it: caller, loop, assertion site>
- Fix: <the structural move; name the existing helper/interface to reuse>
- Rule: <lens / rule name>

## Code judo
<the restructuring that deletes the most complexity, or "none found">

## Checked, not findings
- <pattern that looked like a defect> at path:line - <which counterexample clears it>

## Nits
<optional, at most 3 style-only items>
```

Severity: **blocker** = crash, leak, data loss, silent failure, or a broken contract; **major** = change amplification, drifted copies, unreadable API, file decomposition needed; **minor** = a real, local consequence. An item with any consequence you can show is a finding, not a nit. Nits are only for items with no consequence.

Approve only when there is no blocker or major finding. Do not approve because the code works: a clear structural regression, a missed judo move that removes a defect class, or an unjustified crossing of 1000 lines is a major finding.

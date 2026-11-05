# Sources and reading routes

These sources explain the rules and their exceptions. Code links pin the revision inspected during the 2026-11-04 research. They are selected examples, not approvals of whole repositories or minimum supported Go versions.

## Official Go

- [Effective Go](https://go.dev/doc/effective_go): naming, useful zero values, interfaces, and control flow. Its notice explicitly says that modern feature coverage is incomplete. [Inspected source revision](https://github.com/golang/website/blob/6ac127a09d918cd58bff553eebc9533c2bd26c28/_content/doc/effective_go.html).
- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments): consumer interfaces, synchronous functions, goroutine lifetimes, naming, and copying. [Inspected revision](https://github.com/golang/wiki/blob/fe2268bb04c953cd65bcae752e978912f5cbddaa/CodeReviewComments.md).
- [Organizing a Go module](https://go.dev/doc/modules/layout) and [Package names](https://go.dev/blog/package-names): small starting layouts, package boundaries, and names as callers read them. The older article's GOPATH discussion is historical.
- [Working with Errors in Go 1.13](https://go.dev/blog/go1.13-errors#whether-to-wrap): inspectable errors are API commitments, and implementation errors can be hidden deliberately.
- [When to use generics](https://go.dev/blog/when-generics) and [module Go versions](https://go.dev/ref/mod#go-mod-file-go): match abstractions and APIs to operations and supported toolchains, not novelty.
- [Go Test Comments](https://go.dev/wiki/TestComments): useful diagnostics, semantic comparisons, and tables versus separate tests. Its older `fmt.Errorf` warning needs qualification for `%w`. [Inspected revision](https://github.com/golang/wiki/blob/fe2268bb04c953cd65bcae752e978912f5cbddaa/TestComments.md).

## Google

Read the [style principles](https://github.com/google/styleguide/blob/c03dfce4e1763d032e33696d126e5af4c7de03bf/go/guide.md#style-principles), then [package size](https://github.com/google/styleguide/blob/c03dfce4e1763d032e33696d126e5af4c7de03bf/go/best-practices.md#package-size), errors, interfaces, and testing in the [decisions](https://github.com/google/styleguide/blob/c03dfce4e1763d032e33696d126e5af4c7de03bf/go/decisions.md).

The core guide ranks clarity and simplicity above concision and consistency. Exact internal logging, build, and testing policies are Google conventions. The documents do not prescribe one total declaration order.

## Uber

Read [declaration grouping](https://github.com/uber-go/guide/blob/1d60a91aa5e87d443002e23c21903c49489dbde5/style.md#group-similar-declarations), [error choices](https://github.com/uber-go/guide/blob/1d60a91aa5e87d443002e23c21903c49489dbde5/style.md#error-types), [mutable ownership](https://github.com/uber-go/guide/blob/1d60a91aa5e87d443002e23c21903c49489dbde5/style.md#copy-slices-and-maps-at-boundaries), and [goroutine ownership](https://github.com/uber-go/guide/blob/1d60a91aa5e87d443002e23c21903c49489dbde5/style.md#dont-fire-and-forget-goroutines).

Global prefixes, exact declaration order, and functional-option implementation are house policies. Older atomic-library and loop-rebinding advice needs a target-version check. Its constructor-owned worker is a useful counterexample to mandatory separate Start methods.

## Go standard library

- [`io.Reader`, `copyBuffer`, and `NopCloser`](https://github.com/golang/go/blob/1cfb2cb169decba68818794f4603530923e13805/src/io/io.go): partial results, capability dispatch, and adapters that preserve optional behavior. Read the contract before copying the loop.
- [`context.AfterFunc` connection example](https://github.com/golang/go/blob/1cfb2cb169decba68818794f4603530923e13805/src/context/example_test.go#L185-L223): cancellation interrupts a read through its deadline and separately coordinates callback completion.
- [`sync.Mutex`](https://github.com/golang/go/blob/1cfb2cb169decba68818794f4603530923e13805/src/sync/mutex.go#L17-L33) and [`http.Client`](https://github.com/golang/go/blob/1cfb2cb169decba68818794f4603530923e13805/src/net/http/client.go#L32-L103): useful zeros, copying restrictions, and application-specific timeout requirements.
- [`http.ResponseController`](https://github.com/golang/go/blob/1cfb2cb169decba68818794f4603530923e13805/src/net/http/responsecontroller.go) and [`body.Read`](https://github.com/golang/go/blob/1cfb2cb169decba68818794f4603530923e13805/src/net/http/transfer.go#L854-L895): capability-transparent wrappers and a lock protecting a protocol operation across I/O.

Compatibility preserves historical APIs and behavior. The inspected development revision is not an instruction to adopt every API it contains.

## Go tools

Read [`Analyzer` and `Pass`](https://github.com/golang/tools/blob/1ca5072e6fc605a0575ff1c22811d76c8f542b03/go/analysis/analysis.go), [`checker.Analyze` and execution](https://github.com/golang/tools/blob/1ca5072e6fc605a0575ff1c22811d76c8f542b03/go/analysis/checker/checker.go), then [`analysistest`](https://github.com/golang/tools/blob/1ca5072e6fc605a0575ff1c22811d76c8f542b03/go/analysis/analysistest/analysistest.go).

Observe concrete descriptors with callbacks, locally joined batch work, and expected versus unexpected diagnostics. Cross-process facts and compatibility fields serve tool-specific needs.

## Upspin

Read the [domain contracts](https://github.com/upspin/upspin/blob/334f107fe3d98225d7adfbb35b74e066fbca9875/upspin/doc.go), [pathname representation](https://github.com/upspin/upspin/blob/334f107fe3d98225d7adfbb35b74e066fbca9875/path/path.go), and [error classification](https://github.com/upspin/upspin/blob/334f107fe3d98225d7adfbb35b74e066fbca9875/errors/errors.go) through [client callers](https://github.com/upspin/upspin/blob/334f107fe3d98225d7adfbb35b74e066fbca9875/client/client.go#L378-L408).

Shared protocols and typed categories have real consumers. Upspin's older Kind-first `Is` and custom builder are not a drop-in replacement for modern standard errors.

## WTF

Read [`Dial` and its service contract](https://github.com/benbjohnson/wtf/blob/05bc90c940d5f9e2490fc93cf467d9e8aa48ad63/dial.go), the [SQLite implementation](https://github.com/benbjohnson/wtf/blob/05bc90c940d5f9e2490fc93cf467d9e8aa48ad63/sqlite/dial.go), and [HTTP dependencies](https://github.com/benbjohnson/wtf/blob/05bc90c940d5f9e2490fc93cf467d9e8aa48ad63/http/server.go). Pair them with [Packages as layers, not groups](https://www.gobeyond.dev/packages-as-layers/).

This is teaching code from 2021. The author permits concrete wiring for small applications. Root domain packages, shared mocks, and adapter packages are an application design, not an official standard layout.

## Tailscale

Read [`proxymux`](https://github.com/tailscale/tailscale/blob/274a3f2023e7b1784bd8968d109ec6d2119258a7/net/proxymux/mux.go), [`netmon` lifecycle](https://github.com/tailscale/tailscale/blob/274a3f2023e7b1784bd8968d109ec6d2119258a7/net/netmon/netmon.go#L486-L679), and the [`resolvconffile` leaf package](https://github.com/tailscale/tailscale/blob/274a3f2023e7b1784bd8968d109ec6d2119258a7/net/dns/resolvconffile/resolvconffile.go).

Observe preserved stream bytes, interruption of blocking receives, and a typed format shared by real consumers. Do not transfer process-lifetime assumptions, custom utilities, or unjoined callback behavior to a reloadable library without tracing its owners.

## Prometheus

Follow [`LoadFile` and `GetScrapeConfigs`](https://github.com/prometheus/prometheus/blob/1e227c985bf727258ca2d8d5826cd12f48b16888/config/config.go#L74-L157) through [`reloadConfig`](https://github.com/prometheus/prometheus/blob/1e227c985bf727258ca2d8d5826cd12f48b16888/cmd/prometheus/main.go#L1764-L1816), [`Manager.ApplyConfig`](https://github.com/prometheus/prometheus/blob/1e227c985bf727258ca2d8d5826cd12f48b16888/scrape/manager.go#L364-L471), and [`scrapeLoop.stop`](https://github.com/prometheus/prometheus/blob/1e227c985bf727258ca2d8d5826cd12f48b16888/scrape/scrape.go#L1797-L1805).

Observe preparation before sharing, ordered component application, and the distinction between stopping scraping and later stale-marker cleanup. This path is not a global reload transaction or proof that arbitrary late work is safe.

## etcd

Read [`Session`](https://github.com/etcd-io/etcd/blob/65da638638b28a60419bcfd37e426e4be2cf0ceb/client/v3/concurrency/session.go), the [revision compactor](https://github.com/etcd-io/etcd/blob/65da638638b28a60419bcfd37e426e4be2cf0ceb/server/etcdserver/api/v3compactor/revision.go), and [`Defragment`](https://github.com/etcd-io/etcd/blob/65da638638b28a60419bcfd37e426e4be2cf0ceb/server/etcdserver/server.go#L964-L975).

Observe local cancellation and completion versus remote lease release, worker-local progress, and a lock protecting backend lifetime. Current Raft algorithm code lives in [etcd-io/raft](https://github.com/etcd-io/raft), not this repository's integration layer.

## Caddy

Read [optional module contracts](https://github.com/caddyserver/caddy/blob/c8492563eefcb3c5afbc00f25e7b001ffc6c7d11/modules.go#L288-L317), [dispatch and partial cleanup](https://github.com/caddyserver/caddy/blob/c8492563eefcb3c5afbc00f25e7b001ffc6c7d11/context.go#L366-L466), [activation](https://github.com/caddyserver/caddy/blob/c8492563eefcb3c5afbc00f25e7b001ffc6c7d11/caddy.go#L337-L403), and [HTTP draining](https://github.com/caddyserver/caddy/blob/c8492563eefcb3c5afbc00f25e7b001ffc6c7d11/modules/caddyhttp/app.go#L719-L919).

The host supplies a real plugin protocol and overlapping resource lifetimes. Its global provisioning effects qualify the pointer-swap model. Its [fixed-default pointer bool](https://github.com/caddyserver/caddy/blob/c8492563eefcb3c5afbc00f25e7b001ffc6c7d11/admin.go#L127-L132) also demonstrates presence independently of context-dependent defaults.

## GitHub CLI

Follow [`CloseOptions`, `NewCmdClose`, and `closeRun`](https://github.com/cli/cli/blob/eeb44bc432c0107de002dadd34a61b4e2bd15882/pkg/cmd/issue/close/close.go), then [command tests](https://github.com/cli/cli/blob/eeb44bc432c0107de002dadd34a61b4e2bd15882/pkg/cmd/issue/close/close_test.go) and [typed command errors](https://github.com/cli/cli/blob/eeb44bc432c0107de002dadd34a61b4e2bd15882/pkg/cmdutil/errors.go#L10-L44).

Observe cohesive command organization, narrow dependency fields, late-bound repository overrides, and terminal error ownership. The broad application factory is not a universal dependency-injection design.

## restic

Read the [backend behavioral contract](https://github.com/restic/restic/blob/dd09b6bd01af220b1d5d95c0d4d7d472e05e05c4/internal/backend/backend.go), [lock ownership](https://github.com/restic/restic/blob/dd09b6bd01af220b1d5d95c0d4d7d472e05e05c4/internal/repository/lock.go#L16-L110), [local publication](https://github.com/restic/restic/blob/dd09b6bd01af220b1d5d95c0d4d7d472e05e05c4/internal/backend/local/local.go#L99-L241), and [retry cleanup](https://github.com/restic/restic/blob/dd09b6bd01af220b1d5d95c0d4d7d472e05e05c4/internal/backend/retry/backend_retry.go#L164-L191).

Observe callback retry guarantees, cancellation versus bounded release work, and why cleanup must respect publication and ownership. Storage-specific durability and lease policies are not requirements for all services.

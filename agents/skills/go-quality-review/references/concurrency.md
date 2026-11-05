# Lifecycle and concurrency

## C1. Keep operations synchronous unless an owner needs background work

- Check the caller's required concurrency before adding a goroutine, worker, ticker, listener, or asynchronous callback. Trace acquisition, preparation, use, quiescing, completion, and release through the actual API.
- Finding: hidden concurrency makes callers coordinate work they cannot stop, observe, or safely outlive. Work started per call, construction, or reload with no exit path accumulates workers and retained resources. Serving during a promised config-only check can also acquire resources that the caller cannot release.
- Clear: a constructor may start owned background work with a documented cleanup operation. A request-bounded task needs no ceremonial Start/Stop interface when its lifetime and release are already clear. Deliberate process-lifetime work can omit shutdown when startup creates a bounded set of workers; that exception does not clear accumulating per-call or per-reload work.
- Fix: make the operation synchronous, or retain the smallest explicit owner and cleanup handle. Combine lifecycle phases when the contract permits. Keep validation hooks read-only when their protocol promises that behavior.

## C2. Separate cancellation, unblocking, completion, draining, and release

- Check every blocking read, accept, send, timer, handoff, and callback. Name its owner, exit condition, unblocking mechanism, completion signal, and resources that must remain alive.
- Cancellation requests a stop. It neither joins work nor interrupts arbitrary I/O. Propagate request context through cancellable operations, release returned cancel functions, and connect cancellation to a supported close, deadline, or select where needed.
- Finding: a timeout leaves work blocked, or teardown releases state that surviving work still uses. A stopped ticker does not by itself wake a worker waiting only on its channel.
- Clear: short bounded work needs no context parameter. Stop may quiesce new work without draining existing requests if a surviving owner retains their resources and eventually drains them. Trace all retired generations and the bound on retained resources.
- Fix: unblock before joining, then release resources after their final user. Distinguish local completion from remote lease, lock, or connection release. Give required cleanup I/O a deliberate bounded cancellation policy instead of an already-canceled request context.

Preconditions: Go 1.16 or later. The caller transfers a non-nil `net.Conn` to this completion-only drainer, keeps the `Drainer` at one address without copying it, and always calls `Close`. Incoming bytes are intentionally discarded, and read errors only end the worker. The connection's `Close` returns and unblocks reads. The worker does not call its own `Close`.

```go
type Drainer struct {
	conn net.Conn
	done chan struct{}
	once sync.Once
	err  error
}

func NewDrainer(conn net.Conn) *Drainer {
	d := &Drainer{conn: conn, done: make(chan struct{})}
	go func() {
		defer close(d.done)
		_, _ = io.Copy(io.Discard, conn)
	}()
	return d
}

func (d *Drainer) Close() error {
	d.once.Do(func() {
		d.err = d.conn.Close()
		<-d.done
	})
	return d.err
}
```

## C3. Clean partial failures and roll back in dependency order

- Check each failure after acquisition, including the component whose setup or Start returned an error. Determine whether that component cleans itself or returns partial ownership to its caller.
- Finding: a failed component leaks its own partial resources, or stopping a dependency before its dependent leaves live work using released state. Retrying a failed start can then collide with retained ports or workers.
- Clear: Start is failure-atomic, or a documented cleanup operation safely handles partial initialization. An immediate process exit may discharge process-local ownership only when that is the actual path and no external cleanup obligation remains.
- Fix: choose one cleanup owner for the failing component. Undo successful acquisitions in reverse dependency order, not mechanically in forward iteration order. Preserve the primary failure and any cleanup failures that affect recovery; see [errors](errors.md).

Preconditions: Go 1.20 or later. Components are non-nil, initially stopped, and listed with dependencies first. Each failed Start can leave partial state, and its Close safely cleans that state and waits for its users. On success, the caller owns reverse-order closure. This example has no persistent commit point.

```go
type component interface {
	Start() error
	Close() error
}

func startAll(cs []component) error {
	for i, c := range cs {
		if err := c.Start(); err != nil {
			cleanupErr := c.Close()
			for j := i - 1; j >= 0; j-- {
				cleanupErr = errors.Join(cleanupErr, cs[j].Close())
			}
			return errors.Join(err, cleanupErr)
		}
	}
	return nil
}
```

## C4. Synchronize the whole lifecycle transition

- Check concurrent Start, Close, registration, and callback paths together. State whether every Close caller waits for completion and receives the same result, or whether the API promises only initiation.
- Finding: two callers close one channel, Start registers work after a shutdown wait, or a second Close returns while the first still uses resources that the second caller releases.
- Clear: an existing mutex already protects the related state transition, or one goroutine owns it. An independent once-only action can use `sync.Once`; its concurrent callers wait for the function to return, as in C2.
- Fix: reuse the existing synchronization protocol. A CAS from open to closed only elects an initiator. Add a completion signal and stored result when required, rather than treating the CAS as a join. Wait outside a mutex that workers need. Avoid recursive `Once.Do`, including callbacks that reenter Close.

## C5. Protect invariants, including resource lifetimes

- Check what each mutex guards, its other users, lock order, blocking bounds, and callback reentry. Include the right to use a pointed-to resource, not only the pointer assignment. Keep worker-local state local.
- Finding: a traced cycle deadlocks, an avoidable slow operation stalls unrelated users, or unlocking before I/O allows a resource to be replaced and closed during use.
- Clear: I/O or teardown under a lock can be necessary to protect a lifetime or protocol invariant. A mutex-protected once transition is not inherently worse than `Once` or atomics.
- Fix: shorten the critical section only while preserving the invariant. Prefer snapshots, existing lifetime handles, or a separate narrow lock where justified. Run callbacks outside locks when reentry is allowed. Do not join a worker while holding a lock it needs to exit.

## C6. Prepare before publication and define the reload transaction

- Check the required consistency boundary: one field, one component, one generation, or the whole application. Enumerate failure states, publication points, concurrent reloads, and external effects such as globals, listeners, remote writes, and control-plane changes.
- Finding: readers observe half-prepared state, failure leaves forbidden mixed generations, or overlapping candidates overwrite each other's rollback. A pointer swap alone does not make external effects atomic.
- Clear: a single atomic update needs no candidate object. Ordered best-effort or per-component reload is valid when the application explicitly permits partial success and reports the resulting state.
- Fix: prepare a complete candidate before exposing it where feasible. Serialize the transaction scope that requires isolation, publish prepared state at its actual visibility boundary, and retire old state through C2. Restore or compensate each pre-publication external effect that the contract requires.
- Check overlap before starting a candidate. Ordinary `net.Listen` cannot bind an occupied address merely because a later pointer swap is atomic. Use the existing handoff or sharing protocol, or choose an explicit stop-before-start tradeoff.
- Shared resources need one lifetime owner or existing reference accounting. Release only after the final generation and draining request stop using them. A single owner needs ordinary scoped cleanup, not a pool.

## C7. Make persistent cleanup aware of commit and ownership

- Check what each write, sync, close, rename, or remote publish makes visible. Separate atomic visibility, durability, and retryability. Locate the commit point and the exact object owned by error cleanup.
- Finding: a failure after publication triggers deletion of valid committed data, or cleanup after a failed replacement removes another writer's successful object. Advancing progress before the operation's accepted outcome can also skip required work.
- Clear: pre-commit temporary objects owned exclusively by the operation can be removed. Pure startup rollback without persistent publication follows C3. Filesystem durability steps are unnecessary for an in-memory swap.
- Fix: clean owned temporary state before commit. After commit, preserve the published object and report the actual outcome according to the storage contract. Use the backend's replacement guarantees rather than blanket target deletion on any returned error.

## Sources

See [official concurrency guidance](../sources.md#official-go), [standard-library cancellation contracts](../sources.md#go-standard-library), [Tailscale](../sources.md#tailscale), [etcd](../sources.md#etcd), [Caddy](../sources.md#caddy), [Prometheus](../sources.md#prometheus), and [restic](../sources.md#restic) for distinct ownership, consistency, and cleanup protocols.

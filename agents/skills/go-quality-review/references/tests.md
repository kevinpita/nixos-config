# Tests

## B1. Test the behavior or invariant that can fail

- Check the changed contract and the smallest input, transition, or dependency outcome that exposes a candidate defect. Read nearby tests before asking for another test.
- Finding: a demonstrated defect has no test that would detect it, or changed tests assert incidental state while passing when the promised behavior is broken. Name the incorrect result that escapes detection.
- Clear: a focused internal algorithm or state-machine test can protect a real invariant. Public behavior is preferable when it proves the same contract without expensive unrelated setup. A missing test form or a coverage percentage alone is not a defect.
- Extend an existing behavior test when its setup and checking logic fit. Add a distinct test only for a different failure boundary. Require the test to distinguish correct behavior from the identified failure, not merely assert that code returns or forwards a value.

For example, a reload test should observe that a rejected configuration leaves the required old behavior available. Comparing only the new config struct does not prove that workers survived. A private transition test can be useful when it observes the actual stop/start order.

## B2. Choose the smallest real test boundary

- Check which dependencies are real, substituted, or bypassed. Follow the path from the test's entry point to the effect it asserts.
- Finding: the substitution removes the behavior being claimed, or a test duplicates the implementation's calculation and misses a plausible wrong result. Identify the bypassed boundary or common error.
- Clear: concrete clients with fake transports, consumer-local interfaces, function dependencies, and real local test servers are legitimate seams. Private run functions can test outgoing requests without re-testing flag parsing.
- Exercise the missing boundary rather than mandate public-only tests or a new mocking framework. A wiring test is justified when wiring itself changes observable behavior, such as a parent command override or selected implementation.

Use shared protocol tests when several implementations promise the same behavior. They must test the behavioral contract, including callback count, error classification, and ordering where promised, not just matching method signatures.

## B3. Keep cases and failure output understandable

- Check whether cases share setup and checking logic. Read the failure output a maintainer would receive without opening the table.
- Finding: a table needs per-row mode flags and conditional assertion paths that conceal different behaviors, or a failure omits the relevant operation and case/input so the defect cannot be located from the output.
- Clear: tables suit repeated checking logic. Separate tests or sequential subtests suit different lifecycles. Fatal failure is appropriate when setup failed or continuing cannot produce meaningful results.
- Give cases meaningful names or print relevant inputs. Print actual and expected values with a clear diff direction. Mark setup helpers with `t.Helper()` so failures point at their callers. Keep setup near the tests that need it.

Check error identity or type through the contract's matching API. Exact text is appropriate when wording or formatting is the behavior under test. A bare table index is not a useful substitute for an input or case name.

## B4. Control time, concurrency, and cleanup

- Check how the test waits for work, releases resources, and isolates mutable dependencies. Trace goroutines and callbacks that can survive a test or subtest.
- Finding: a real schedule can make assertions race unfinished work, leaked resources affect later tests, or shared mutation lets parallel cases change one another's inputs or dependencies.
- Clear: a bounded timeout can guard against a hung test. It is not a substitute for a completion signal. Package globals can be unavoidable legacy seams, but their mutation must remain isolated and restored.
- Synchronize on observable work or completion. Use existing fake time or supported `testing/synctest` where suitable. Prefer per-instance dependencies to test-mutated globals. Cancel work before cleanup waits when that is the ownership contract.

Check the module version before recommending `t.Context`, `testing/synctest`, or loop-variable workarounds. Use [Concurrency](concurrency.md) for the lifetime defect and [Types](types.md) for aliased data rather than repeat those findings as test-style complaints.

## B5. Use generated inputs for a meaningful property

- Check parsers and transformations of untrusted input for properties such as no panic, valid round-trip, or preservation of a documented invariant. Establish which inputs the property admits.
- Finding: a demonstrated boundary defect escapes coverage, or an existing fuzz target accepts a broken property because its oracle excludes the failing inputs or ignores the relevant result.
- Clear: missing fuzzing alone is not a finding. Not every parser has a simple round-trip property, especially when it normalizes or intentionally discards input. Tables and regressions can establish particular boundaries.
- Keep a regression for the actual failure. Add fuzzing when generated inputs can probe a useful invariant. Targets must be deterministic and isolate mutable state. A normal test run exercises seeds; generated fuzz exploration requires an actual fuzz run.

## Sources

See [Go testing guidance](../sources.md#official-go), [Google test structure](../sources.md#google), and the [CLI](../sources.md#github-cli), [tools](../sources.md#go-tools), and [restic](../sources.md#restic) routes. These demonstrate complementary test boundaries, not one required framework or package location.

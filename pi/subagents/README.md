# Child tool compatibility

`modules/pi.nix` gives native subagents an explicit extension list containing only `pi-web-access/index.ts`. This keeps `pi-colours` and other parent UI extensions out of children. Agent tool allowlists still apply. Researcher and evidence-auditor agents already request all four web tools. Other agents need an explicit tool declaration before they can use them.

`../extensions/subagents.ts` loads a patched copy of the installed `pi-subagents` package. The npm package entry disables automatic extension loading but keeps its skills and prompts. The original npm package is not changed.

The patch fixes two problems in pi-subagents 0.67.0:

- A parent extension that replaces a built-in tool, such as the `pi-colours` bash renderer, must not make that tool appear absent.
- The host built-in tool list must not remove extension tool names. Child extensions supply these tools. The existing child registration check must still verify them.

The patch does not change capability ceilings, explicit tool exclusions, or extension-denial rules.

Patched copies use stable content-keyed paths under `~/.pi/agent/npm/.subagent-patches/`. Copies remain after parent exit because detached children and resumed runs can still need them. Do not delete a copy while a run can still use it. Package or patch changes create a new cache entry. Patch application uses zero fuzz and fails visibly if an upstream update is incompatible.

## Validation

Run with Node 24 or newer and GNU patch installed:

```bash
node --test pi/subagents/*.test.mjs
```

The planner tests use the installed package by default. Set `PI_SUBAGENTS_PACKAGE` to test another package directory. `TEST_UNPATCHED=1` reproduces the two original planner failures. The tests exercise the real planner and capability module with unrelated MCP discovery and configuration imports stubbed.

After applying the Nix configuration and reloading Pi, run a read-only native scout and researcher smoke test. Verify actual bash, web search, fetch, stored-result retrieval, and source-check calls. A child that merely reports missing tools is a failed test, even if its run status is completed. External CLI agents have their own tool setup and do not use this native configuration.

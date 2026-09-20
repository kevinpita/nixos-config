# Workflow web integration

This folder adapts the upstream workflow package so child agents can use the parent's web tools, configuration, authentication, and stored results. It is integration code, not a directory for user workflow definitions.

## Where changes belong

- Change `inherit-web-tools.patch` when the upstream workflow package needs different integration points.
- Change `web-tools.js` and its type declarations when the web-tool adapter needs to change.
- Change `../extensions/web-workflows.ts` for package loading and patch application.
- Change `../../modules/pi.nix` for package selection and deployment.

The bridge loads the web and workflow extensions together. Keep automatic package loading coordinated with it so extensions are not registered twice. It patches a separate copy rather than modifying the installed upstream package.

## Maintaining compatibility

Update this code when an upstream change breaks the adapter or when workflow agents need different web behavior. Do not bypass agent tool restrictions or expose unrelated parent extensions to make an integration work.

After a change, rebuild and restart Pi. Check that child agents can use the allowed web tools and retrieve stored results. Include resumed runs and worktree agents when their loading path is affected. If a patch fails to apply, review the upstream change rather than weakening patch checks.

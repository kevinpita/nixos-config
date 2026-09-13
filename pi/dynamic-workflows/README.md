The local Pi extension `../extensions/web-workflows.ts` loads pi-web-access and this patched workflow package together. Their package entries disable automatic extension loading so each factory runs once.

Workflow agents receive the active `web_search`, `source_check`, `fetch_content`, and `get_search_content` implementations from the parent. `web_fetch` aliases `fetch_content` for existing research workflows. Calls use the parent's web configuration, authentication, and result storage. Workflow searches set `workflow: "none"` to avoid opening a browser curator.

The patch adds these tools before the workflow agent's tool policy is applied. It also covers worktree agents and resumed runs. Other host extensions remain unloaded in workflow children.

The workflow package is unpinned. Run `pi update npm:@quintinshaw/pi-dynamic-workflows` to update it, or `pi update --extensions` to update all packages. Pi does not check for a newer package on every launch.

On each extension load, the bridge copies the installed package under `~/.pi/agent/npm/.workflow-patches/` and applies `inherit-web-tools.patch` with zero fuzz. It replaces the copied web tool module, then loads the copy. npm manages all dependency versions. The installed package stays unchanged, concurrent Pi sessions use separate copies, and normal process exit removes each copy.

If the patch no longer applies, the bridge fails with the installed version and patch error. Fix the patch here, rebuild, and reload Pi. Verify normal and research agents, worktree agents, tool-name restrictions, stored-result retrieval, and session replacement after an update.

## Environment

- The host runs NixOS. If a tool is missing, run it with `nix shell nixpkgs#<tool> -c <command>`. Do not install it.
- Command output is in Spanish. To parse it, run the command with `LC_ALL=C`, or check the exit code.
- git uses difftastic as its external diff. To read or apply a patch, use `git --no-pager diff --no-ext-diff --no-color`.
- `docker` talks to rootless Podman. Bind-mounted files get mapped uids.
- `~/.omp/agent` is generated from `~/nixos-config`. Edit the files there: `agents/` for AGENTS.md and shared skills, `omp/` for omp config, commands, and extensions (see `omp/README.md`). New files need `git add -N` before a Nix build sees them.

## Pushes and PRs

- Do not push until the user asks you to.
- Do not edit PR titles or bodies, and do not post comments, until the user asks you to.

## Kubernetes

- "k" means Kubernetes. In the user's zsh, `k` is an alias for `kubectl`.
- The user uses kubie to select the context and the namespace. The agent shell inherits the kubie session (`KUBIE_ACTIVE=1`, `KUBECONFIG` points to the kubie file).
- The `k` alias does not exist in the agent's non-interactive shell. Run `kubectl` in tool calls.
- In commands for the user, write `k` instead of `kubectl`.
- Do not add `-n`, `--namespace`, `--context`, `--kube-context`, or `--kubeconfig` to `kubectl` or `helm` commands, unless the user asks for a different namespace or context. This applies to commands that you run and to commands that you give to the user.
- If the user names a context or namespace, it is possibly already active. To verify, run `kubectl config current-context` and `kubectl config view --minify -o jsonpath='{..namespace}'`.
- Use only read-only commands on a cluster, for example `get`, `describe`, `logs`, `top`, and `helm diff`. Ask the user before a command that changes the cluster, for example `apply`, `patch`, `delete`, `scale`, `rollout restart`, `exec`, or `helm upgrade`.
- Query a cluster only when the task needs live state. For questions about a repo or its config, read the repo.
- If no kubie session is active (no current context, or `KUBECONFIG` is not set), stop and ask the user to start kubie. Do not use another kubeconfig or `--context`.
- Ask the user before you read or decode Secret data.

## Live networks

- Never send transactions or other writes to mainnet or testnet on your own. Test and prove on a local network.
- Read-only queries to mainnet or testnet are OK when the task needs live state.

## Public repos

- In a public repo, do not reveal an undisclosed security issue in branch names, commits, PRs, or comments. Do not write private tracker references or private advisory IDs, and do not describe the bug, its trigger, or its impact. Use neutral wording, for example `chore: ...`. Ask before you make any new security detail public.

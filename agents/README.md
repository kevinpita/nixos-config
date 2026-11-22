# Agent instructions and skills

This folder owns agent content that does not depend on one harness. Harness modules, such as `modules/omp.nix`, install these files into the location that each harness reads.

## What belongs here

| Path | Change it for |
| --- | --- |
| `AGENTS.md` | Global instructions for all projects. Project-specific rules belong in the relevant project's instruction file. |
| `RULES.md` | Environment facts and hard rules that every agent must follow, also a subagent. Keep it short. |
| `skills/` | Reusable task guidance and its supporting references. Extend the existing skill when it already owns the task. |
| `evals/` | Eval suites that measure a skill against a no-skill baseline. No harness installs them. |

Harness settings and files that use harness-specific syntax belong in the folder of that harness, for example [`omp/`](../omp/README.md).

## Where the files go

| Harness | `AGENTS.md` | `RULES.md` | `skills/` |
| --- | --- | --- | --- |
| omp | `~/.omp/agent/AGENTS.md` | `~/.omp/agent/RULES.md` | `~/.omp/agent/skills` |
| Antigravity CLI | `~/.gemini/config/AGENTS.md` | the end of `~/.gemini/config/AGENTS.md` | `~/.gemini/config/skills.json` |
| Claude Code | `~/.claude/CLAUDE.md` | the end of `~/.claude/CLAUDE.md` | not installed |

omp gives `AGENTS.md` to the main session only. Task subagents get `RULES.md`, so a rule that a subagent must follow belongs there.

omp and Antigravity CLI use the same catalog in [`modules/omp.nix`](../modules/omp.nix). It includes the skills in this directory, the `forklab` skill from its CLI package, the `impeccable` skill from [`pbakaus/impeccable`](https://github.com/pbakaus/impeccable) with its pinned engine binary, and selected skills from [`felipebasurto/unslop-ui`](https://github.com/felipebasurto/unslop-ui), [`obsidianmd/obsidian-skills`](https://github.com/obsidianmd/obsidian-skills), [`grafana/skills`](https://github.com/grafana/skills), [`github/gh-stack`](https://github.com/github/gh-stack), [`github/awesome-copilot`](https://github.com/github/awesome-copilot), [`mattpocock/skills`](https://github.com/mattpocock/skills), and [`cursor/plugins`](https://github.com/cursor/plugins). Flake inputs pin the external skills. Both agents load the pinned pstack plugin, which provides `bro`.

## Applying changes

Run `just switch` from the repository root to deploy changes, then restart the harness to load them. Edit the source here rather than the installed files.

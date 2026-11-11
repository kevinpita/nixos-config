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
| omp | `~/.omp/agent/AGENTS.md` | `~/.omp/agent/RULES.md` | `~/.omp/agent/skills`, without `bro` because pstack ships its own |
| Claude Code | `~/.claude/CLAUDE.md` | the end of `~/.claude/CLAUDE.md` | not installed |

omp gives `AGENTS.md` to the main session only. Task subagents get `RULES.md`, so a rule that a subagent must follow belongs there.

omp also gets the `forklab` skill. The forklab package ships that skill, so it stays at the same version as the installed CLI. Change it in the forklab repository.

omp also gets selected interface design skills from [`jakubkrehel/skills`](https://github.com/jakubkrehel/skills). The `interface-skills` flake input pins that repository, and `modules/omp.nix` lists which skill folders to link. Run `nix flake update interface-skills` to get a newer version.

## Applying changes

Run `just switch` from the repository root to deploy changes, then restart the harness to load them. Edit the source here rather than the installed files.

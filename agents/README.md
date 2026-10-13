# Agent instructions and skills

This folder owns agent content that does not depend on one harness. Harness modules, such as `modules/omp.nix`, install these files into the location that each harness reads.

## What belongs here

| Path | Change it for |
| --- | --- |
| `AGENTS.md` | Global instructions for all projects. Project-specific rules belong in the relevant project's instruction file. |
| `skills/` | Reusable task guidance and its supporting references. Extend the existing skill when it already owns the task. |

Harness settings and files that use harness-specific syntax belong in the folder of that harness, for example [`omp/`](../omp/README.md).

## Where the files go

| Harness | `AGENTS.md` | `skills/` |
| --- | --- | --- |
| omp | `~/.omp/agent/AGENTS.md` | `~/.omp/agent/skills`, without `bro` because pstack ships its own |
| Antigravity | not installed | `~/.gemini/antigravity-cli/skills` |

## Applying changes

Run `just switch` from the repository root to deploy changes, then restart the harness to load them. Edit the source here rather than the installed files.

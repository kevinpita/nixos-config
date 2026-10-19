---
name: research
description: Interview the user, then find and prove the best way to do something with a multi-model survey, prototypes, adversarial review, and verification.
argument-hint: What do you want to find the best way to do?
disable-model-invocation: true
---

# Research

Find the best way to do one thing, and prove that it works. You are the **lead**. You own the brief, every decision, the verification, and the report. Subagents give you **leads**: claims that you check before you use them.

Open a todo list with one entry per phase before you start: Interview, Plan, Survey, Shortlist, Build, Attack, Verify, Judge, Report.

## Roster

Spawn each subagent with `task` and the agent named below. Each agent pins its model through a role in `omp/config.yml`.

| Agent | Model | Role |
| --- | --- | --- |
| `opus` | Claude Opus 5.5 | Strongest model by far. Surveys, builds every prototype, fixes confirmed findings. |
| `gpt` | GPT-6.1 Sol | Surveys, attacks, and is the cross-family judge. |
| `fable` | Claude Fable 5.1 | Surveys and attacks. |
| `glm-flash` | GLM 5.3 Flash | Explores unusual angles and attacks. Advice only. |
| `deepseek` | DeepSeek V4 Flash | Explores unusual angles and attacks. Advice only. |

Only Opus writes code that can become the result. The other models advise, explore, and attack. Their output is a lead until you or Opus confirm it. If a model fails or returns nothing, continue without it and record the dropout. A model never reviews or judges its own work.

## 1. Interview

Use `ask` in rounds of up to four questions, with two to four options each. Put your recommended option first. Find facts yourself from the repo, files, and tools before you ask. Ask the user only for decisions. The argument, if given, is the topic.

Resolve these decisions:

- **Topic**: the exact problem in one sentence.
- **Result type**: working code, a design decision, or knowledge only.
- **Scope**: where the work lives (repo, package, files, or greenfield) and what is out of scope.
- **Constraints**: hard rules that a candidate must not break.
- **Rubric**: 3 to 6 criteria that you can grade, in priority order.
- **Proof of works**: the exact test, benchmark, or command that must pass. For knowledge-only results, the proof is a primary source for each key claim.
- **Depth**: Light, Standard, or Full (see Plan).
- **Sources**: repo only, or repo and web.

The interview is done when every decision has an answer or the user defers it.

## 2. Plan

Show the user the plan before you spawn anything:

- The brief: topic, result type, scope, constraints, rubric, proof of works.
- A table with each model, its role in this run, and the phases it runs in.
- The subagent count for the chosen depth:

| Depth | Survey | Build | Attack | Judge | About |
| --- | --- | --- | --- | --- | --- |
| Light | 5 models | 1 written case by you | 2 attackers on the case | you only | 7 subagents |
| Standard | 5 models | 2 candidates | 2 attackers per candidate | GPT + you | 12 subagents |
| Full | 5 models | 3 candidates | 4 attackers per candidate | GPT + you | 21 subagents |

Get approval with `ask`. Then write the brief to `local://research-brief.md`. Every subagent task points to it, because subagents do not see this conversation.

## 3. Survey

Spawn all five models in one `task` batch. Give each model a different lens:

| Model | Lens |
| --- | --- |
| Opus | The standard approach that experts use, and how it fits this codebase. |
| GPT | Prior art, known failures, and post-mortems of similar work. |
| Fable | Alternatives that the standard approach misses. |
| GLM | An unusual or contrarian approach. |
| DeepSeek | The simplest or cheapest approach that meets the rubric. |

Each model returns 2 to 5 approaches. For each approach: how it works, tradeoffs against the rubric, failure modes, and a source for each factual claim. A claim without a source is marked `[INFERENCE]`.

The survey is done when each model returned a result or is recorded as a dropout.

## 4. Shortlist

Merge the approaches and remove duplicates. Check the key claims of each approach against its sources. Pick the approaches that are really different and can meet the constraints: 1 for Light, 2 for Standard, 3 for Full. Show the user the shortlist, and the reason for each dropped approach, with `ask`. The first option is "continue".

## 5. Build

Every candidate becomes one **candidate artifact**, which the Attack, Verify, and Judge phases use. Pick the mode from the brief:

- **Prototype**: the result type is working code, and the depth is Standard or Full. The artifact is a git worktree.
- **Written case**: every other run. The artifact is `local://research-<candidate>.md`.

For a prototype, spawn one Opus subagent per candidate in one batch. Give each one its own git worktree at `/tmp/research-<slug>/<candidate>`. Each candidate must include the proof-of-works test, and must return the worktree path, the commands it ran, and their output.

For a written case, the artifact states the recommendation, how it works, the tradeoffs against the rubric, each key claim with its primary source, and the known risks. At Light depth, write it yourself. At Standard and Full depth, spawn one Opus subagent per candidate in one batch to write it.

## 6. Attack

Spawn the attackers in one batch. Give each attacker one candidate artifact and the brief. Use a different model family from the author when possible. Rotate GPT, Fable, GLM, and DeepSeek so that each candidate gets different attackers.

An attacker returns findings. Each finding has a concrete failing input, a scenario with steps, or a source that contradicts a claim. An opinion without one of these is not a finding.

## 7. Verify

Check the proof of each candidate yourself:

- **Prototype**: run the proof-of-works test.
- **Written case**: open the primary source for each key claim and confirm that it says what the artifact claims. A claim that you cannot confirm becomes `[INFERENCE]` or is removed. When the result type is working code and nothing was built, report the proof-of-works test as not run.

Reproduce each finding yourself. For each finding, record **confirmed** or **rejected**, with the evidence.

Send the confirmed findings for a candidate to one Opus subagent to fix in the same artifact. Then check the proof again. Drop a candidate that you cannot fix.

Verification is done when every finding has a status and the proof of every remaining candidate holds in your own check.

## 8. Judge

Score each remaining candidate against the rubric, one criterion at a time. For Standard and Full depth, spawn GPT as an independent judge with the brief and the candidate artifacts, and without your scores. When you and GPT pick a different winner, read both reasons and explain the result.

## 9. Report

Give the report in chat:

- The recommendation and the main reason for it.
- A table of candidates and rubric scores, with the proof result for each candidate.
- The findings: confirmed and fixed, confirmed and still open, and rejected.
- The dropped approaches and why.
- The evidence: commands you ran, their output, and the source links.
- Dropouts and open risks.

If the run built prototypes, ask the user if they want to keep the worktrees. Remove the worktrees that they do not keep with `git worktree remove`.

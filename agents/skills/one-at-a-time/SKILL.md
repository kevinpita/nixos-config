---
name: one-at-a-time
description: Walk through a list one point per message, waiting for the user's comment on each. Use when the user asks to go point by point, one at a time, one by one, or to explain or review a list, plan, or set of findings step by step.
---

Walk the user through a list one **point** per message, so they can read and comment on each before the next arrives.

## Pick the list

Use the list the user names. Otherwise use the most recent multi-point content in the conversation: a numbered or bulleted list, a plan, a set of findings, review comments, steps. When the current task is about to produce such a list (a plan, an explanation of a process), write it as points and deliver it through this skill instead of all at once.

When the walk starts, create a new **decision log** for it. Name the log after the walk: a short slug of the list's subject plus the start time, such as `local://walk-<slug>-<HHMM>.md` in omp, or the same name in the OS temporary directory in another harness. Keep the log outside the workspace. On its first line, write the walk's subject and point count. Name the log path in the first message of the walk, so that the path stays in the conversation after a compaction. Use this log until the walk ends.

## Each turn

1. Open with the position: `Point 3 of 7: <short title>`.
1. Present that single point in full: what it is, why it matters, and anything the user needs to judge it. Keep later points out of the message.
1. End the turn with a short prompt for the user's comment.

The user's reply decides the next turn:

- A question, objection, or correction: answer it and stay on the same point until the user moves on.
- A comment that changes later points: say which points change, update the remaining list, and keep the count accurate.
- "next", "ok", "go on", or similar: present the next point.
- "skip" or "stop": skip the point, or end the walk.

When the user gives a decision on a point, write it at once to the walk's decision log, one line per point: the position, the short title, and the decision in the user's words or as a short restatement.

## Finish

The walk is done when every point has been presented and the user has moved past it. Read the decision log of the current walk only, then close with a recap: each point as one line, plus every change or decision the user made along the way. The log keeps the decisions through a long walk or a compaction.

This skill covers discussion only. Act on a point (edit files, run commands) when the user asks for it during the walk.

---
name: one-at-a-time
description: Walk through a list one point per message, waiting for my comment on each.
disable-model-invocation: true
---

Walk the user through a list one **point** per message, so they can read and comment on each before the next arrives.

## Pick the list

Use the list the user names. Otherwise use the most recent multi-point content in the conversation: a numbered or bulleted list, a plan, a set of findings, review comments, steps. When the current task is about to produce such a list (a plan, an explanation of a process), write it as points and deliver it through this skill instead of all at once.

## Each turn

1. Open with the position: `Point 3 of 7: <short title>`.
1. Present that single point in full: what it is, why it matters, and anything the user needs to judge it. Keep later points out of the message.
1. End the turn with a short prompt for the user's comment.

The user's reply decides the next turn:

- A question, objection, or correction: answer it and stay on the same point until the user moves on.
- A comment that changes later points: say which points change, update the remaining list, and keep the count accurate.
- "next", "ok", "go on", or similar: present the next point.
- "skip" or "stop": skip the point, or end the walk.

## Finish

The walk is done when every point has been presented and the user has moved past it. Close with a recap: each point as one line, plus every change or decision the user made along the way.

This skill covers discussion only. Act on a point (edit files, run commands) when the user asks for it during the walk.

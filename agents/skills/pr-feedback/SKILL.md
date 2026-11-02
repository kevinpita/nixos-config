---
name: pr-feedback
description: Use when the user pastes review feedback (a reviewer, CodeRabbit, another model) or asks to address the review comments of a PR.
---

1. Get the feedback: the pasted text, or the unresolved review comments of the PR (`gh api`).
1. Verify each point against the current code. Check whether the working tree already fixes it. Verdict per point: accept, reject, or already fixed, with the reason and the code evidence.
1. Show the verdicts as one short table. Then walk the accepted and unclear points one at a time: what it is in one sentence, the impact, the proposed fix, and "Fix, skip, or explain more?".
1. Fix only the points that the user approved. Run the affected tests and lint. Make a local commit. Do not push.
1. Draft one short reply per comment. Post the replies only when the user asks.

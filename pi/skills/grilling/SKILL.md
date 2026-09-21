---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Agree on the interview's scope before exploring the design tree.

Work the tree in **rounds**. The **frontier** is every in-scope decision whose prerequisites are already settled: the questions you can ask now without guessing at answers you haven't heard yet. Use `ask_user_question` for each round, with up to four independent questions and two to four options per question. Put your recommended option first and label it as recommended. Wait for the answers before the next round. If the frontier exceeds four questions, carry the remaining questions into later rounds.

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), look it up yourself before asking that question. The _decisions_ are the user's: put each to them and wait.

The interview is complete when every in-scope decision is resolved or explicitly deferred, dependencies are accounted for, and the user confirms the decision summary through `ask_user_question`. Record deferred decisions and their consequences in that summary. Start implementation only after the user authorizes it. A documentation-enabled interview may record confirmed decisions as it proceeds.

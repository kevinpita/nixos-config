---
name: visual-pr
description: Write a visual pull request description that shows the shape of a change.
disable-model-invocation: true
metadata:
  source: https://github.com/humanlayer/skills/tree/main/plugins/visual-pr/skills/visual-pr
---

# Visual PR

Describe the current task as a concise pull request body with a structural view that helps reviewers understand the change. Use the requested PR if one is named; otherwise look for a PR on the current branch. If there is no PR, describe the local branch without creating or pushing one.

1. Read the repository's PR template and instructions. Inspect the PR diff or branch diff, relevant commits, and enough surrounding code to explain the behavior and ownership. Read related task material when it exists.
1. Draft the body using the repository's template. When it has no template, use these sections:
   - **Why the change:** one sentence on the problem and result.
   - **Special things to note:** one to three bullets on reviewer-relevant risks, migrations, compatibility, or deliberate omissions. Write `None.` if there are none.
   - **Change outline:** a compact structural view of the implementation.
1. In the outline, choose only views that explain this change: data structures, SQL or API contracts, pseudocode, a shallow file tree, component trees, or call and data flow. Prefer a `diff` block for a change to an existing shape. Show the complete shape when it is new or a diff would hide context. Use real names and omit unrelated details.
1. Show the draft to the user. Create or edit a PR only when the user explicitly asks. Push only when the user explicitly asks. Do not commit, create task files, or write a PR body as a side effect of drafting.
1. If an authorized PR update succeeds, report its URL. Otherwise report the draft and any missing context. Do not claim a PR was updated until the command succeeds.

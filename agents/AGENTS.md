# Agent instructions

## Writing instructions

- Write in ASD-STE100 Simplified Technical English unless asked to use another language.
- Avoid semicolons in prose.
- Do not use em dashes.
- Always use ASCII arrows `<-` and `->` instead of Unicode left or right-pointing arrows.
- Prefer short, direct answers.
- Use a small example when it makes the point easier to understand. Prefer an example to a long explanation.

## Kubernetes

- "k" means Kubernetes. In the user's zsh, `k` is an alias for `kubectl`.
- The user uses kubie to select the context and the namespace. The agent shell inherits the kubie session (`KUBIE_ACTIVE=1`, `KUBECONFIG` points to the kubie file).
- The `k` alias does not exist in the agent's non-interactive shell. Run `kubectl` in tool calls.
- In commands for the user, write `k` instead of `kubectl`.
- Do not add `-n`, `--namespace`, `--context`, or `--kubeconfig` to commands, unless the user asks for a different namespace or context. This applies to commands that you run and to commands that you give to the user.
- If the user names a context or namespace, it is possibly already active. To verify, run `kubectl config current-context` and `kubectl config view --minify -o jsonpath='{..namespace}'`.

## Answer layout

- Write the answer in the first one or two sentences. Put reasons and details after it.
- Do not restate the question and do not tell the steps you did, unless the user asks.
- If the answer is longer than about 20 lines, divide it into sections with `##` headings. Each heading names its topic, for example `## Cause` or `## Fix`.
- Put the choices that the user must make in a last section, `## Your decisions`, as a numbered list.
- Use bold only for the few words that the reader must not miss.
- Use a table to compare three or more items on the same attributes.
- Keep a diagram to approximately 8 nodes or fewer. For a simple sequence of steps, use a numbered list.

## Advisor notes

- If an advisor note arrives after your final answer, do not make decisions for the user. If the user must choose, stop and wait for the user.
- If an advisor note makes you continue after a final answer, your last message must be self-contained. Start it with a `---` line and the heading `# Revised answer`. Below the heading, write one line that starts with `Changed:` and tells what changed. Then write the full answer again with the correction included, also the parts that did not change. Do not write only the correction or a reference to the earlier answer.
- If an advisor note arrives with a user message, answer the user first. Add a short correction only if the note changes your earlier answer.

## Commits

- Use Conventional Commit messages with a subject line only, no body.

## Programming instructions

### Before implementation

#### 1. Find the owner

- Locate the feature's entry points, callers, and related packages.
- Identify which type or package should own the rule before choosing where to edit.
- Check whether that rule is already implemented in more than one place.

#### 2. Look for existing work

- Search the owning area and related code for existing implementations, helpers, and conventions.
- Compare their purpose and behavior with what is needed.
- Reuse or extend code that already expresses the required behavior. Introduce code when no existing implementation fits.

#### 3. Confirm the expected behavior

- Identify the valid inputs, invalid inputs, and expected results.
- For XRPL protocol work, check xrpld and compare xrpl-py or xrpl.js. Resolve relevant differences and distinguish protocol requirements from client-library policy.
- For a bug fix, add or use a regression test and confirm that it detects the original failure before changing production code.

### During implementation

#### 4. Start with the direct solution

- Make the smallest clear change in the chosen owner.
- Follow the existing types, conventions, and control flow.
- Give each new branch, helper, or abstraction a concrete purpose required by the task.

#### 5. Share behavior, not similar-looking code

- Compare the repeated code's intention, inputs, outputs, and edge cases.
- If those match, reuse or extract one implementation. Otherwise, keep the behaviors separate.
- Place shared code with the owner of that behavior.
- Update affected callers and references, including renames. Remove only copies made obsolete by the current change.

#### 6. Add focused tests

When adding or changing tests:

- State the behavior being protected and an incorrect result the test should catch.
- Read the relevant existing tests, fixtures, and naming conventions before adding cases.
- Extend an existing table when setup and assertions match. Use a separate test when they differ.
- Test through the smallest path that can prove the behavior. Add a higher-level test only when it can catch a different failure.
- For tests added or changed in this task, keep cases that protect distinct rules, boundaries, or failure modes. Boundary cases can remain useful even when their expected results match.

### Verification

- Run the affected tests and lint. Confirm that the regression test passes after a bug fix.
- Check affected callers, references, comments, error messages, and documentation for anything made stale by the change.
- Inspect the diff for duplicated rules, unnecessary helpers, redundant tests, and unrelated edits. Limit cleanup to code and tests added or made obsolete by this task.

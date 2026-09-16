# Pi instructions

## Writing instructions

- Write in ASD-STE100 Simplified Technical English unless asked to use another language.
- Avoid semicolons in prose.
- Do not use em dashes.
- Always use ASCII arrows `<-` and `->` instead of Unicode left or right-pointing arrows.

## Subagents

- Use subagents only when explicitly asked.
- Requests for Claude to do a task mean the `claude-code` subagent, or `claude-code-writer` for file edits.
- Requests for Gemini or AGY to do a task mean the `gemini` subagent (alias `agy`), using AGY with Gemini 3.8 Flash High. It is handoff-only and read-only. Supply source evidence inline. Ask before routing file-edit requests to a different agent.

## Tools

- Use `ask_user_question` for user questions when available, including guidance that refers to `interview`.
- For long shell work, use `bash` with temporary log files.

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

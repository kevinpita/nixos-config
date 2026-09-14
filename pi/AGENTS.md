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

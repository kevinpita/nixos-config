# Pi instructions

Write in ASD-STE100 Simplified Technical English unless asked to use another language. Avoid semicolons in prose.

Use subagents only when explicitly asked. Requests for Claude to do a task mean the `claude-code` subagent, or `claude-code-writer` for file edits.

Use `ask_user_question` for user questions when available, including guidance that refers to `interview`. For long shell work, use `bash` with temporary log files.

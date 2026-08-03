# Split Session

`/split N` keeps the current Pi session and opens `N - 1` additional Herdr tabs. Each tab starts Pi with `--fork`, so it inherits the active conversation branch while writing to an independent session file.

Example:

```text
/split 5
```

This leaves the current tab in place and creates four background tabs. Focus stays on the current tab.

## Requirements

- Pi must be running inside Herdr.
- The current Pi session must be persisted.
- `N` must be between 2 and 12.

## Working directory

Every created tab starts in the current Pi working directory. Conversation state is isolated, but files are shared. Coordinate concurrent edits or create separate Git worktrees before editing the same files from multiple tabs.

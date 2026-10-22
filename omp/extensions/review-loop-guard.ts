import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// The review-loop skill creates this marker at setup and removes it at stop.
const marker = join(homedir(), ".omp", "agent", "review-loop.active");

export default function (pi) {
  pi.on("tool_call", async event => {
    if (event.toolName !== "bash" || !existsSync(marker)) return;
    const command = String(event.input?.command ?? "");
    if (/\bgit\b[^\n;&|]*\bpush\b/.test(command) || /\bgh\s+pr\s+(create|merge)\b/.test(command)) {
      return {
        block: true,
        reason: `review-loop: git push, gh pr create, and gh pr merge are blocked while ${marker} exists. The loop commits locally only. Remove the file if no loop is running.`,
      };
    }
  });
}

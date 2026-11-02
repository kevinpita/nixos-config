import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join, resolve } from "node:path";

// The review-loop skill creates `review-loop.active` in the repository's git
// common dir at setup and removes it at stop. A push is blocked only when the
// repository it targets has that marker, so other repositories stay free.
const PUSH = /\bgit\b[^\n;&|]*\bpush\b|\bgh\s+pr\s+(create|merge)\b/;

function marker(dir: string): string | undefined {
	const result = spawnSync("git", ["-C", dir, "rev-parse", "--path-format=absolute", "--git-common-dir"], {
		encoding: "utf8",
	});
	if (result.status !== 0) return undefined;
	const path = join(result.stdout.trim(), "review-loop.active");
	return existsSync(path) ? path : undefined;
}

// Directories that each push in the command runs against. Follows `cd <dir>`
// segments and `git -C <dir>`. Other pushes run in the tracked cwd.
function pushTargets(command: string, cwd: string): string[] {
	const targets: string[] = [];
	let dir = cwd;
	for (const segment of command.split(/&&|\|\||[;|\n]/)) {
		const words = segment.trim().split(/\s+/).map(word => word.replace(/^(['"])(.*)\1$/, "$2"));
		if (words[0] === "cd" && words[1]) {
			dir = resolve(dir, words[1]);
			continue;
		}
		if (!PUSH.test(segment)) continue;
		let target = dir;
		for (let i = 0; i < words.length - 1; i++) {
			if (words[i] === "-C") target = resolve(target, words[i + 1]);
		}
		targets.push(target);
	}
	return targets;
}

export default function (pi) {
	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return;
		const command = String(event.input?.command ?? "");
		if (!PUSH.test(command)) return;
		const cwd = resolve(ctx.cwd, String(event.input?.cwd ?? "."));
		for (const target of pushTargets(command, cwd)) {
			const path = marker(target);
			if (!path) continue;
			return {
				block: true,
				reason: `review-loop: git push, gh pr create, and gh pr merge are blocked in this repository while ${path} exists. The loop commits locally only. Remove the file if no loop is running.`,
			};
		}
	});
}

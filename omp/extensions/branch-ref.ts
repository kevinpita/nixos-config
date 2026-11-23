/**
 * `##name` in the prompt completes a git branch, with fuzzy search. A search
 * sorts all branches by match quality. Without one, and between equal matches,
 * local branches come first, then remote ones, each group newest first.
 * Accepting a row replaces the token with "branch `name`", so the model reads
 * it as a branch. `#123` and the `#` prompt actions stay with omp.
 */
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { type AutocompleteItem, type AutocompleteProvider, fuzzyRank } from "@oh-my-pi/pi-tui";
import { isLocalExecutionDraft } from "@oh-my-pi/pi-tui/prompt/skill-tokens";

// `##` after a token boundary, the same boundary that omp requires for `#123`.
const TOKEN_RE = /(?:^|[\s"'`(<=])(##[^\s#]*)$/;
const REF_RE = /^refs\/(heads|remotes)\/(.+)$/;
const FORMAT = "%(refname)%09%(committerdate:relative)%09%(contents:subject)";

interface BranchItem extends AutocompleteItem {
	remote: boolean;
}

async function listBranches(pi: ExtensionAPI, cwd: string, signal?: AbortSignal): Promise<BranchItem[]> {
	const result = await pi.exec(
		"git",
		["for-each-ref", "--sort=-committerdate", `--format=${FORMAT}`, "refs/heads", "refs/remotes"],
		{ cwd, signal, timeout: 2000 },
	);
	if (result.code !== 0) return [];
	const branches = result.stdout.split("\n").flatMap(line => {
		const [ref, date, ...subject] = line.split("\t");
		const match = ref.match(REF_RE);
		// `origin/HEAD` is an alias of the remote's default branch.
		if (!match || (match[1] === "remotes" && match[2].endsWith("/HEAD"))) return [];
		return [
			{
				value: match[2],
				label: match[2],
				description: `${date} · ${subject.join("\t")}`,
				icon: "\u{E0A0}",
				remote: match[1] === "remotes",
			},
		];
	});
	// A stable sort, so each group keeps the date order of git.
	return branches.sort((a, b) => Number(a.remote) - Number(b.remote));
}

export default function (pi: ExtensionAPI) {
	let cwd = () => process.cwd();
	let registered = false;

	const wrap = (current: AutocompleteProvider): AutocompleteProvider => ({
		async getSuggestions(lines, cursorLine, cursorCol, signal, onPartial) {
			const token = (lines[cursorLine] ?? "").slice(0, cursorCol).match(TOKEN_RE)?.[1];
			// omp runs a `!` or `$ ` draft as code, and in a shell the inserted backticks would execute the name.
			if (token === undefined || isLocalExecutionDraft(lines.join("\n"))) {
				return current.getSuggestions(lines, cursorLine, cursorCol, signal, onPartial);
			}
			const branches = await listBranches(pi, cwd(), signal);
			const items = fuzzyRank(branches, token.slice(2), branch => branch.value).map(result => result.item);
			return items.length > 0 ? { items, prefix: token } : null;
		},
		applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
			if (!("remote" in item)) return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
			const line = lines[cursorLine] ?? "";
			// The popup can be one keystroke behind, so replace the token that is in the text now.
			const token = line.slice(0, cursorCol).match(TOKEN_RE)?.[1] ?? prefix;
			const start = cursorCol - token.length;
			const text = `branch \`${item.value}\` `;
			const next = [...lines];
			next[cursorLine] = line.slice(0, start) + text + line.slice(cursorCol);
			return { lines: next, cursorLine, cursorCol: start + text.length };
		},
		// omp installs this object as the provider, so its optional methods must stay reachable.
		getInlineHint: current.getInlineHint?.bind(current),
		trySyncSlashCompletion: current.trySyncSlashCompletion?.bind(current),
		trySyncModelMentionCompletion: current.trySyncModelMentionCompletion?.bind(current),
		trySyncInlineReplace: current.trySyncInlineReplace?.bind(current),
		getForceFileSuggestions: current.getForceFileSuggestions?.bind(current),
		shouldTriggerFileCompletion: current.shouldTriggerFileCompletion?.bind(current),
	});

	pi.on("session_start", async (_event, ctx) => {
		cwd = () => ctx.sessionManager.getCwd();
		// omp keeps every registered factory, so register once.
		if (registered) return;
		registered = true;
		ctx.ui.addAutocompleteProvider(wrap);
	});
}

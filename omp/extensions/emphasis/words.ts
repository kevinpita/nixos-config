// Adapted from johnlindquist/pi-emphasis, revision f884b736. See LICENSE.
export type PillTone = "error" | "warning" | "success" | "danger" | "mode" | "owner" | "neutral";

const WORDS: Record<PillTone, readonly string[]> = {
	error: ["failed", "blocked", "broken", "unsafe", "fail", "failing", "error", "rejected", "down"],
	warning: ["needs you", "decision", "unverified", "partial", "skipped", "in progress", "pending", "at risk", "needs review", "waiting", "review", "todo", "stale", "draft"],
	success: ["done", "passed", "observed", "fixed", "live", "recommended", "keep", "pass", "ready", "merged", "safe", "verified", "shipped", "ok", "approved", "complete", "completed", "finished", "healthy"],
	danger: ["costs money", "destructive", "irreversible"],
	mode: ["brainstorm", "investigate", "preview", "implement", "qualify"],
	owner: ["owned", "shared", "foreign"],
	neutral: ["inferred", "new", "changed", "optional"],
};
const tones = new Map<string, PillTone>();
for (const tone of ["error", "warning", "success", "danger", "mode", "owner", "neutral"] as const) {
	for (const word of WORDS[tone]) tones.set(word, tone);
}
const KNOWN = [...tones.keys()].sort((a, b) => b.length - a.length);
const CHECK = "\uf00c";
const CROSS = "\uf00d";
const CLOCK = "\uf017";
const PILL_ICONS: Readonly<Record<string, string>> = {
	done: CHECK, passed: CHECK, verified: CHECK,
	observed: "\uf06e", recommended: "\uf005", fixed: "\uf0ad", live: "\uf135", shipped: "\uf135", approved: "\uf164",
	failed: CROSS, rejected: CROSS, blocked: "\uf05e", broken: "\uf127", unsafe: "\uf132", down: "\uf063",
	"needs you": "\uf007", decision: "\uf126", unverified: "\uf128", "at risk": "\uf071",
	"in progress": "\uf110", pending: CLOCK, partial: "\uf042", skipped: "\uf04e",
	inferred: "\uf0eb", new: "\uf067", changed: "\uf040", optional: "\uf10c", "costs money": "\uf155",
	destructive: "\uf1f8", irreversible: "\uf023", review: "\uf06e", stale: "\uf1da", draft: "\uf044", safe: "\uf132",
	brainstorm: "\uf0eb", investigate: "\uf002", preview: "\uf06e", implement: "\uf0ad", qualify: "\uf0c3",
	owned: "\uf007", shared: "\uf0c0", foreign: "\uf023", keep: "\uf08d", ready: CHECK, merged: "\uf126", healthy: "\uf004", todo: "\uf0ae",
};
const SYNONYMS: Readonly<Record<string, string>> = {
	complete: "Done", completed: "Done", ok: "Done", finished: "Done", pass: "Passed",
	fail: "Failed", failing: "Failed", error: "Failed", waiting: "Pending", "needs review": "Review",
};
const LABEL_ICONS: Readonly<Record<string, string>> = {
	finding: "\uf002", terminal: "\uf120", folder: "\uf07b", file: "\uf15b", branch: "\uf126", review: "\uf06e",
	ideas: "\uf0eb", cause: "\uf0e7", fix: "\uf0ad", risk: "\uf071", limits: "\uf071", next: "\uf061", rollback: "\uf0e2",
	undo: "\uf0e2", options: "\uf0ca", result: "\uf11e", why: "\uf059", how: "\uf013", cost: "\uf155", rule: "\uf0e3",
	example: "\uf121", checked: "\uf00c", pills: "\uf02b", colors: "\uf1fc", icons: "\uf005", scoreboard: "\uf080",
	verdict: "\uf0e3", effect: "\uf140", evidence: "\uf06e", plan: "\uf0ae", status: "\uf012", decision: "\uf126",
};
const ACTION_ICONS: Readonly<Record<string, string>> = {
	check: "\uf046", do: "\uf0a4", next: "\uf061", unblock: "\uf09c", left: "\uf141", run: "\uf04b", guard: "\uf132", undo: "\uf0e2", see: "\uf08e",
};
const OWN_ICON = /^\s*([\ue000-\uf8ff]|[\u{f0000}-\u{ffffd}])\s*/u;

export function splitLabel(label: string): { text: string; icon: string | undefined; tone: PillTone } {
	const own = label.match(OWN_ICON);
	const text = (own ? label.slice(own[0].length) : label).replace(/\s+/g, " ").trim();
	const lower = text.toLowerCase();
	const known = KNOWN.find(word => lower === word || (lower.startsWith(word) && /[ :]/.test(lower[word.length])));
	const canonical = known ? SYNONYMS[known] : undefined;
	const key = (canonical ?? known ?? lower).toLowerCase();
	return {
		text: canonical && known ? canonical + text.slice(known.length) : text,
		icon: own?.[1] ?? PILL_ICONS[key],
		tone: tones.get(key) ?? "neutral",
	};
}

export function labelIcon(label: string, leading: boolean): string | undefined {
	if (OWN_ICON.test(label)) return undefined;
	const key = label.replace(/[:\s]+$/, "").trim().toLowerCase();
	return (label.trimEnd().endsWith(":") ? ACTION_ICONS[key] : undefined) ?? (leading ? LABEL_ICONS[key] : undefined);
}

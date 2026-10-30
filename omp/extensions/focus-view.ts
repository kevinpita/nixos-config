/**
 * Ctrl+L (or /focus) opens a fullscreen view that shows only the answers of
 * the main agent, one prompt at a time, newest first. Left/Right go to older
 * and newer answers. While the agent works on the newest prompt, its page shows
 * a spinner and the prompt. Ctrl+L, Esc, or q closes the view.
 *
 * omp ignores extension shortcuts on ctrl+l (a reserved key), so this reads
 * raw terminal input, which runs before omp's own keybindings. It replaces the
 * ctrl+l toggle of live voice mode.
 */
import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import {
	getMarkdownTheme,
	isKeyRelease,
	Markdown,
	matchesKey,
	parseSgrMouse,
	theme,
	truncateToWidth,
	type TUI,
	visibleWidth,
} from "@oh-my-pi/pi-tui";

// Lines longer than this are harder to read, so a wide terminal gets margins.
const MAX_COLUMNS = 100;
const WHEEL_LINES = 3;
const SPINNER_MS = 80;

interface RunState {
	running: boolean;
	startedAt: number;
}

type Block = { type: string; text?: string };
type Entry = {
	type: string;
	customType?: string;
	message?: { role: string; content: unknown; stopReason?: string };
};

// The heading that AGENTS.md asks for, after an optional `---` line, when an
// advisor note makes the agent rewrite its answer.
const REVISED_ANSWER = /^(?:-{3,}\s*\n\s*)?#\s+Revised answer\b/i;

interface Turn {
	prompt: string;
	answer: string | undefined;
	/** Stop reason of the newest assistant message, which explains a missing answer. */
	stopReason: string | undefined;
}

function textOf(content: unknown): string {
	if (typeof content === "string") return content.trim();
	if (!Array.isArray(content)) return "";
	return (content as Block[])
		.filter(block => block.type === "text" && block.text)
		.map(block => block.text)
		.join("\n\n")
		.trim();
}

/**
 * One turn per user prompt. Its answer is the last assistant message with
 * text and no tool calls before the next prompt. After an advisor note, a
 * later message replaces the answer only when it starts with the revised
 * answer heading, so a short reply to the note does not hide the answer.
 */
function turnsOf(ctx: ExtensionContext): Turn[] {
	const turns: Turn[] = [];
	let turn: Turn | undefined;
	let afterNote = false;
	for (const entry of ctx.sessionManager.getBranch() as Entry[]) {
		if (entry.type === "custom_message" && entry.customType === "advisor") {
			afterNote = true;
			continue;
		}
		const message = entry.message;
		if (entry.type !== "message" || !message) continue;
		if (message.role === "user") {
			turn = { prompt: textOf(message.content), answer: undefined, stopReason: undefined };
			turns.push(turn);
			afterNote = false;
		}
		if (!turn || message.role !== "assistant") continue;
		turn.stopReason = message.stopReason;
		const blocks = Array.isArray(message.content) ? (message.content as Block[]) : [];
		const text = textOf(message.content);
		if (!text || blocks.some(block => block.type === "toolCall")) continue;
		if (afterNote && turn.answer && !REVISED_ANSWER.test(text)) continue;
		turn.answer = text;
	}
	return turns;
}

function missingAnswer(turn: Turn | undefined): string {
	if (!turn) return "No answer yet.";
	if (turn.stopReason === "aborted") return "The run was interrupted before it gave an answer.";
	if (turn.stopReason === "error") return "The run ended with an error before it gave an answer.";
	return "No answer for this prompt.";
}

function elapsed(ms: number): string {
	const seconds = Math.floor(ms / 1000);
	return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
}

function centered(text: string, width: number): string {
	return " ".repeat(Math.max(0, Math.floor((width - visibleWidth(text)) / 2))) + text;
}

class FocusView {
	/** Index into the pages, or undefined to follow the newest prompt. */
	#pinned: number | undefined;
	#scroll = 0;
	#source: string | undefined;
	#columns = 0;
	#lines: string[] = [];
	#spinner: NodeJS.Timeout | undefined;

	constructor(
		private readonly tui: TUI,
		private readonly ctx: ExtensionContext,
		private readonly run: RunState,
		private readonly close: () => void,
	) {}

	/**
	 * Turns with an answer, plus the newest turn in any case, so that its page
	 * shows the spinner or why it has no answer. Older turns without an answer
	 * (interrupted or steered prompts) are left out.
	 */
	#pages(): Turn[] {
		const turns = turnsOf(this.ctx);
		return turns.filter((turn, index) => turn.answer || index === turns.length - 1);
	}

	render(width: number): string[] {
		const height = Math.max(4, this.tui.terminal.rows);
		const columns = Math.max(20, Math.min(MAX_COLUMNS, width - 4));
		const pages = this.#pages();
		const last = pages.length - 1;
		const index = Math.min(this.#pinned ?? last, last);
		if (index === last) this.#pinned = undefined;
		const turn = pages[index];
		const waiting = this.run.running && index === last;
		this.#syncSpinner(waiting);
		const position = pages.length > 1 ? `${index + 1}/${pages.length}  ` : "";
		const header = theme.fg("dim", truncateToWidth(`${position}${turn?.prompt.split("\n")[0] ?? ""}`, columns));
		const rows = waiting
			? this.#renderWaiting(height - 3, width)
			: this.#renderAnswer(height - 3, columns, " ".repeat(Math.max(0, Math.floor((width - columns) / 2))), turn);
		const keys = [pages.length > 1 ? "Left/Right answers" : "", rows.scrollable ? "Up/Down scroll" : "", "Esc close"];
		return [
			centered(header, width),
			"",
			...rows.lines,
			theme.fg("dim", truncateToWidth(centered(`${rows.percent}${keys.filter(Boolean).join("  ")}`, width), width)),
		];
	}

	#renderWaiting(body: number, width: number) {
		const frames = theme.spinnerFrames;
		const frame = frames[Math.floor(Date.now() / SPINNER_MS) % frames.length] ?? "*";
		const status = `${theme.fg("accent", frame)}  ${theme.fg("muted", `Working  ${elapsed(Date.now() - this.run.startedAt)}`)}`;
		const lines = new Array<string>(body).fill("");
		lines[Math.max(0, Math.floor(body / 2) - 1)] = centered(status, width);
		return { lines, scrollable: false, percent: "" };
	}

	#renderAnswer(body: number, columns: number, margin: string, turn: Turn | undefined) {
		const source = turn?.answer ?? `_${missingAnswer(turn)}_`;
		if (source !== this.#source) {
			this.#source = source;
			this.#columns = 0;
			this.#scroll = 0;
		}
		if (columns !== this.#columns) {
			this.#columns = columns;
			const style = theme.hasColor("assistantMessageText")
				? { color: (text: string) => theme.fg("assistantMessageText", text), proseFg: true }
				: undefined;
			const markdown = new Markdown(source, 0, 0, getMarkdownTheme(), style);
			this.#lines = markdown.render(columns).map(line => margin + line);
		}
		const maxScroll = Math.max(0, this.#lines.length - body);
		this.#scroll = Math.min(Math.max(0, this.#scroll), maxScroll);
		const lines = this.#lines.slice(this.#scroll, this.#scroll + body);
		while (lines.length < body) lines.push("");
		const percent = maxScroll > 0 ? `${Math.round((this.#scroll / maxScroll) * 100)}%  ` : "";
		return { lines, scrollable: maxScroll > 0, percent };
	}

	#syncSpinner(waiting: boolean): void {
		if (waiting && !this.#spinner) {
			this.#spinner = setInterval(() => this.tui.requestRender(), SPINNER_MS);
			this.#spinner.unref?.();
		} else if (!waiting) {
			this.#stopSpinner();
		}
	}

	#stopSpinner(): void {
		clearInterval(this.#spinner);
		this.#spinner = undefined;
	}

	#move(step: number): void {
		const last = this.#pages().length - 1;
		const index = Math.max(0, Math.min(last, (this.#pinned ?? last) + step));
		this.#pinned = index === last ? undefined : index;
	}

	handleInput(data: string): void {
		if (data.startsWith("\x1b[<")) {
			const wheel = parseSgrMouse(data)?.wheel;
			if (wheel) this.#scroll += wheel * WHEEL_LINES;
			this.tui.requestRender();
			return;
		}
		const page = Math.max(1, this.tui.terminal.rows - 4);
		if (matchesKey(data, "escape") || data === "q") this.close();
		else if (matchesKey(data, "left") || data === "h") this.#move(-1);
		else if (matchesKey(data, "right") || data === "l") this.#move(1);
		else if (matchesKey(data, "up") || data === "k") this.#scroll -= 1;
		else if (matchesKey(data, "down") || data === "j") this.#scroll += 1;
		else if (matchesKey(data, "pageUp") || data === "b") this.#scroll -= page;
		else if (matchesKey(data, "pageDown") || data === " ") this.#scroll += page;
		else if (matchesKey(data, "home") || data === "g") this.#scroll = 0;
		else if (matchesKey(data, "end") || data === "G") this.#scroll = Number.MAX_SAFE_INTEGER;
		this.tui.requestRender();
	}

	invalidate(): void {
		this.#columns = 0;
	}

	dispose(): void {
		this.#stopSpinner();
	}
}

export default function (pi: ExtensionAPI) {
	const run: RunState = { running: false, startedAt: 0 };
	let close: (() => void) | undefined;
	let refresh: (() => void) | undefined;

	const toggle = (ctx: ExtensionContext): void => {
		if (close) {
			close();
			return;
		}
		let view: FocusView | undefined;
		void ctx.ui
			.custom<void>(
				(tui, _theme, _keybindings, done) => {
					close = () => done(undefined);
					refresh = () => tui.requestRender();
					view = new FocusView(tui, ctx, run, close);
					return view;
				},
				{
					overlay: true,
					overlayOptions: { width: "100%", maxHeight: "100%", margin: 0, fullscreen: true },
				},
			)
			.finally(() => {
				view?.dispose();
				close = undefined;
				refresh = undefined;
			});
	};

	// omp drops raw input listeners when it switches sessions (/new, /resume,
	// fork), so bind again after each switch.
	let unbind: (() => void) | undefined;
	const bind = (ctx: ExtensionContext): void => {
		if (!ctx.hasUI || ctx.agent?.kind !== "main") return;
		unbind?.();
		unbind = ctx.ui.onTerminalInput(data => {
			if (isKeyRelease(data) || !matchesKey(data, "ctrl+l")) return undefined;
			toggle(ctx);
			return { consume: true };
		});
	};
	pi.on("session_start", async (_event, ctx) => bind(ctx));
	pi.on("session_switch", async (_event, ctx) => {
		run.running = false;
		bind(ctx);
	});

	pi.on("agent_start", async (_event, ctx) => {
		if (ctx.agent?.kind !== "main") return;
		run.running = true;
		run.startedAt = Date.now();
		refresh?.();
	});

	pi.on("agent_end", async (event, ctx) => {
		if (ctx.agent?.kind !== "main" || event.willContinue) return;
		run.running = false;
		refresh?.();
	});

	pi.registerCommand("focus", {
		description: "Show only the answers, newest first (also ctrl+l)",
		handler: async (_args, ctx) => toggle(ctx),
	});
}

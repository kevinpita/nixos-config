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
import type { ExtensionAPI, ExtensionContext, ExtensionUiHost } from "@oh-my-pi/pi-coding-agent";
import { decodeInput } from "@oh-my-pi/pi-tui/driver/input/decoder";
import { renderMarkdown } from "@oh-my-pi/pi-tui/text/markdown/render";
import { truncate, visibleWidth } from "@oh-my-pi/pi-tui/text/width";
import { currentTheme } from "@oh-my-pi/pi-tui/theme/runtime";
import type { ResolvedTheme } from "@oh-my-pi/pi-tui/theme/theme";
import { emphasize } from "./emphasis/render.ts";

// Lines longer than this are harder to read, so a wide terminal gets margins.
const MAX_COLUMNS = 100;
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
	#theme: ResolvedTheme | undefined;
	#lines: string[] = [];
	#spinner: NodeJS.Timeout | undefined;

	constructor(
		private readonly ui: ExtensionUiHost,
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
		const theme = currentTheme();
		const height = Math.max(4, this.ui.size().rows);
		const columns = Math.max(20, Math.min(MAX_COLUMNS, width - 4));
		const pages = this.#pages();
		const last = pages.length - 1;
		const index = Math.min(this.#pinned ?? last, last);
		if (index === last) this.#pinned = undefined;
		const turn = pages[index];
		const waiting = this.run.running && index === last;
		this.#syncSpinner(waiting);
		const position = pages.length > 1 ? `${index + 1}/${pages.length}  ` : "";
		const header = theme.fg("dim", truncate(`${position}${turn?.prompt.split("\n")[0] ?? ""}`, columns));
		const rows = waiting
			? this.#renderWaiting(theme, height - 3, width)
			: this.#renderAnswer(theme, height - 3, columns, " ".repeat(Math.max(0, Math.floor((width - columns) / 2))), turn);
		const keys = [pages.length > 1 ? "Left/Right answers" : "", rows.scrollable ? "Up/Down scroll" : "", "Esc close"];
		return [
			centered(header, width),
			"",
			...rows.lines,
			theme.fg("dim", truncate(centered(`${rows.percent}${keys.filter(Boolean).join("  ")}`, width), width)),
		];
	}

	#renderWaiting(theme: ResolvedTheme, body: number, width: number) {
		const frames = theme.symbols.spinnerFrames;
		const frame = frames[Math.floor(Date.now() / SPINNER_MS) % frames.length] ?? "*";
		const status = `${theme.fg("accent", frame)}  ${theme.fg("muted", `Working  ${elapsed(Date.now() - this.run.startedAt)}`)}`;
		const lines = new Array<string>(body).fill("");
		lines[Math.max(0, Math.floor(body / 2) - 1)] = centered(status, width);
		return { lines, scrollable: false, percent: "" };
	}

	#renderAnswer(theme: ResolvedTheme, body: number, columns: number, margin: string, turn: Turn | undefined) {
		const source = turn?.answer ?? `_${missingAnswer(turn)}_`;
		if (source !== this.#source) {
			this.#source = source;
			this.#columns = 0;
			this.#scroll = 0;
		}
		if (columns !== this.#columns || theme !== this.#theme) {
			this.#columns = columns;
			this.#theme = theme;
			// The transcript draws answers with this color when the theme sets it.
			const textStyle = theme.has("assistantMessageText") ? "assistantMessageText" : undefined;
			this.#lines = renderMarkdown(emphasize(source), columns, { theme, textStyle }).map(line => margin + line);
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
			this.#spinner = setInterval(() => this.ui.requestRender(), SPINNER_MS);
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

	/** The host sends each key press and paste as raw input, and draws the view again after it. */
	handleInput(data: string): void {
		const page = Math.max(1, this.ui.size().rows - 4);
		for (const event of decodeInput(data)) {
			if (event.type !== "key") continue;
			switch (event.key.id) {
				case "escape":
				case "q":
					this.close();
					break;
				case "left":
				case "h":
					this.#move(-1);
					break;
				case "right":
				case "l":
					this.#move(1);
					break;
				case "up":
				case "k":
					this.#scroll -= 1;
					break;
				case "down":
				case "j":
					this.#scroll += 1;
					break;
				case "pageUp":
				case "b":
					this.#scroll -= page;
					break;
				case "pageDown":
				case "space":
					this.#scroll += page;
					break;
				case "home":
				case "g":
					this.#scroll = 0;
					break;
				case "end":
				case "shift+g":
					this.#scroll = Number.MAX_SAFE_INTEGER;
					break;
			}
		}
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
		void ctx.ui
			.custom<void>(
				(ui, _theme, _keybindings, done) => {
					close = () => done(undefined);
					refresh = () => ui.requestRender();
					return new FocusView(ui, ctx, run, close);
				},
				{ overlay: true, fullscreen: true },
			)
			.finally(() => {
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
			const pressed = decodeInput(data).some(
				event => event.type === "key" && event.key.kind !== "release" && event.key.id === "ctrl+l",
			);
			if (!pressed) return undefined;
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

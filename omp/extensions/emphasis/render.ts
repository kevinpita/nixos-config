import type { Token } from "@oh-my-pi/pi-utils/marked";
import {
	getThemeEpoch,
	isValidThemeColor,
	lexDocument,
	theme,
	type Theme,
	type ThemeBg,
	type ThemeColor,
} from "@oh-my-pi/pi-tui";
import { labelIcon, splitLabel, type PillTone } from "./words.ts";

type Piece = { from: number; to: number };
type Located = { from: number; to: number; pieces: Piece[] };
type Edit = Piece & { text: string };

export interface Palette {
	bold(text: string): string;
	mark(text: string): string;
	pills: Record<PillTone, { label: string; cap: string }>;
	icons: boolean;
	roundCaps: boolean;
}

export function createPalette(
	colors: Pick<Theme, "fg" | "getFgAnsi" | "getBgAnsi">,
	options: { icons?: boolean; roundCaps?: boolean; boldColor?: ThemeColor } = {},
): Palette {
	const tone = (fg: ThemeColor, bg: ThemeBg) => {
		const background = colors.getBgAnsi(bg);
		if (!background || background === "\x1b[49m") {
			const foreground = colors.getFgAnsi(fg === "text" ? "accent" : fg);
			return { label: foreground + "\x1b[7m", cap: foreground };
		}
		return {
			label: background + colors.getFgAnsi(fg),
			cap: background.replaceAll("\x1b[48;", "\x1b[38;").replace(/\[(4|10)([0-7])m/g, (_, prefix: string, n: string) => `[${prefix === "4" ? "3" : "9"}${n}m`),
		};
	};
	const solid = (code: number) => ({ label: `\x1b[${code}m\x1b[7m`, cap: `\x1b[${code}m` });
	return {
		bold: text => `\x1b[1m${colors.fg(options.boldColor ?? "mdLink", text)}\x1b[22m`,
		mark: text => colors.fg(/[✓✔]/.test(text) ? "success" : /[✗✘]/.test(text) ? "error" : text === "→" ? "accent" : "dim", text),
		pills: {
			success: tone("success", "toolSuccessBg"),
			error: tone("error", "toolErrorBg"),
			warning: tone("warning", "toolPendingBg"),
			neutral: tone("text", "selectedBg"),
			danger: solid(31),
			mode: solid(36),
			owner: solid(34),
		},
		icons: options.icons ?? true,
		roundCaps: options.roundCaps ?? true,
	};
}

function pill(label: string, palette: Palette): string {
	const { text, icon, tone } = splitLabel(label);
	const style = palette.pills[tone];
	const word = (palette.icons && icon ? `${icon} ${text}` : text).replace(/ /g, "\u00a0");
	const body = `${style.label}\x1b[1m${palette.roundCaps ? word : `\u00a0${word}\u00a0`}\x1b[22;27m\x1b[39m\x1b[49m`;
	return palette.roundCaps ? `${style.cap}\ue0b6\x1b[39m${body}${style.cap}\ue0b4\x1b[39m` : body;
}

// Match the native lexer's normalization, but keep edits in the original source.
function sourceView(source: string): { text: string; offset(index: number): number } {
	if (!/[\r\t]/.test(source)) return { text: source, offset: index => index };
	let text = "";
	const offsets = [0];
	for (let i = 0; i < source.length; i++) {
		const char = source[i];
		if (char === "\r") {
			if (source[i + 1] === "\n") i++;
			text += "\n";
			offsets.push(i + 1);
		} else if (char === "\t") {
			text += "    ";
			offsets.push(i, i, i, i + 1);
		} else {
			text += char;
			offsets.push(i + 1);
		}
	}
	return { text, offset: index => offsets[index] };
}

// Nested token raws omit list indentation and quote prefixes. Locate each line
// inside its parent, never searching past a missing token into later code.
function locate(source: string, raw: string, start: number, end: number): Located | undefined {
	if (!raw) return undefined;
	const pieces: Piece[] = [];
	let cursor = start;
	for (const [i, line] of raw.split("\n").entries()) {
		if (i > 0) {
			const newline = source.indexOf("\n", cursor);
			if (newline < 0 || newline >= end || !/^ *$/.test(source.slice(cursor, newline))) return undefined;
			cursor = newline + 1;
		}
		const from = source.indexOf(line, cursor);
		if (from < 0 || from + line.length > end) return undefined;
		if (i > 0 && !/^[ >]*$/.test(source.slice(cursor, from))) return undefined;
		pieces.push({ from, to: from + line.length });
		cursor = from + line.length;
	}
	return { from: pieces[0].from, to: cursor, pieces };
}

export function decorate(markdown: string, palette: Palette): string {
	if (!/\[\[|\*\*|__|[✓✔✗✘→├└#]/.test(markdown)) return markdown;
	const view = sourceView(markdown);
	const source = view.text;
	const edits: Edit[] = [];

	const prose = (site: Located, strong: boolean, icon: string | undefined) => {
		for (const piece of site.pieces) {
			const from = view.offset(piece.from);
			const to = view.offset(piece.to);
			const original = markdown.slice(from, to);
			let text = original.replace(/\[\[([^[\]\n\r]{1,32})\]\]|[✓✔✗✘→]|[├└]──/g, (match, label: string | undefined) =>
				label === undefined ? palette.mark(match) : label.trim() ? pill(label, palette) + (strong ? "\x1b[1m" : "") : match,
			);
			if (icon && original.trim()) {
				text = `${icon} ${text}`;
				icon = undefined;
			}
			if (strong && text) text = palette.bold(text);
			if (text !== original) edits.push({ from, to, text });
		}
	};

	const walk = (tokens: readonly Token[], start: number, end: number, strong = false, icon?: string, tableCell = false) => {
		let cursor = start;
		let preceding = "";
		for (const token of tokens) {
			const raw = tableCell ? token.raw.replaceAll("|", "\\|") : token.raw;
			const site = locate(source, raw, cursor, end);
			if (!site) return;
			cursor = site.to;
			switch (token.type) {
				case "text":
					if (token.tokens) walk(token.tokens, site.from, site.to, strong, icon, tableCell);
					else prose(site, strong, icon);
					icon = undefined;
					break;
				case "strong":
				case "em":
				case "del": {
					const leading = /^(?:[├└]──\s*)?$/.test(preceding.slice(preceding.lastIndexOf("\n") + 1).trim());
					const prefix = palette.icons && token.type === "strong" ? labelIcon(token.text, leading) : undefined;
					const width = token.type === "em" ? 1 : 2;
					walk(token.tokens ?? [], site.from + width, site.to - width, strong || token.type === "strong", prefix, tableCell);
					break;
				}
				case "heading": {
					const marker = /^ {0,3}#{1,6}\s+/.exec(token.raw)?.[0].length ?? 0;
					const title = locate(source, token.text, site.from + marker, site.to);
					const prefix = palette.icons ? labelIcon(token.text, true) : undefined;
					if (title && prefix) edits.push({ from: view.offset(title.from), to: view.offset(title.from), text: `${prefix} ` });
					break;
				}
				case "list":
					walk(token.items, site.from, site.to);
					break;
				case "list_item": {
					const marker = /^ *(?:[-*+]|\d+[.)]) +(?:\[[ xX]\] +)?/.exec(token.raw)?.[0].length ?? 0;
					walk(token.tokens ?? [], site.from + marker, site.to);
					break;
				}
				case "blockquote": {
					const marker = /^ *> ?/.exec(token.raw)?.[0].length ?? 0;
					walk(token.tokens ?? [], site.from + marker, site.to);
					break;
				}
				case "paragraph":
					walk(token.tokens ?? [], site.from, site.to, strong, icon, tableCell);
					icon = undefined;
					break;
				case "table": {
					const rows = [token.header, ...token.rows];
					for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
						const piece = site.pieces[rowIndex === 0 ? 0 : rowIndex + 1];
						if (!piece) break;
						let from = piece.from;
						let to = piece.to;
						while (from < to && /\s/.test(source[from])) from++;
						while (to > from && /\s/.test(source[to - 1])) to--;
						if (source[from] === "|") from++;
						if (source[to - 1] === "|" && source[to - 2] !== "\\") to--;
						let cellFrom = from;
						let cellIndex = 0;
						for (let at = from; at <= to; at++) {
							if (at < to && (source[at] !== "|" || source[at - 1] === "\\")) continue;
							const cell = rows[rowIndex][cellIndex++];
							if (!cell) break;
							walk(cell.tokens, cellFrom, at, false, undefined, true);
							cellFrom = at + 1;
						}
					}
					break;
				}
				// Code, escapes, links, images, HTML, math and custom tokens stay verbatim.
			}
			preceding += token.raw;
		}
	};

	walk(lexDocument(markdown), 0, source.length);
	if (edits.length === 0) return markdown;
	const out: string[] = [];
	let cursor = 0;
	for (const edit of edits) {
		out.push(markdown.slice(cursor, edit.from), edit.text);
		cursor = edit.to;
	}
	out.push(markdown.slice(cursor));
	return out.join("");
}

const color = process.env.OMP_EMPHASIS_COLOR ?? "mdLink";
if (!isValidThemeColor(color)) throw new Error(`Invalid OMP_EMPHASIS_COLOR: ${color}`);
const options = {
	boldColor: color,
	icons: process.env.OMP_EMPHASIS_ICONS !== "0",
	roundCaps: process.env.OMP_EMPHASIS_ROUND_CAPS !== "0",
};
let cached: { epoch: number; palette: Palette } | undefined;

export function emphasize(markdown: string): string {
	const epoch = getThemeEpoch();
	if (cached?.epoch !== epoch) cached = { epoch, palette: createPalette(theme, options) };
	return decorate(markdown, cached.palette);
}

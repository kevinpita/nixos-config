import { afterAll, describe, expect, test } from "bun:test";
import { stripVTControlCharacters } from "node:util";
import { getMarkdownTheme, initTheme, Markdown, setTheme, stopThemeWatcher, theme } from "@oh-my-pi/pi-tui";
import { createPalette, decorate, emphasize } from "../render.ts";

await initTheme(false, "nerd", false, "dark", "dark");
afterAll(stopThemeWatcher);
const palette = createPalette(theme, { icons: false, roundCaps: false });
const plain = (source: string) => stripVTControlCharacters(source).replace(/\u00a0/g, " ");
const render = (source: string) => new Markdown(source, 0, 0, getMarkdownTheme()).render(100).map(plain).join("\n");

describe("pills", () => {
	test.each([
		["Failed", "Failed", "error"], ["Needs you", "Needs you", "warning"],
		["Done", "Done", "success"], ["Costs money", "Costs money", "danger"],
		["Implement", "Implement", "mode"], ["Shared", "Shared", "owner"],
		["Anything else", "Anything else", "neutral"], ["Completed", "Done", "success"],
		["Fail: 3 tests", "Failed: 3 tests", "error"], ["Passed 12/12", "Passed 12/12", "success"],
		["Donezo", "Donezo", "neutral"], ["  needs   YOU ", "needs YOU", "warning"],
	] as const)("%s keeps its meaning and tone", (label, word, tone) => {
		const output = decorate(`[[${label}]]`, palette);
		expect(plain(output)).toBe(` ${word} `);
		expect(output).toContain(palette.pills[tone].label);
	});

	test("keeps long and empty labels literal", () => {
		const source = `[[${"x".repeat(33)}]] [[ ]]`;
		expect(decorate(source, palette)).toBe(source);
	});

	test("draws rounded caps and a supplied icon", () => {
		const output = decorate("[[\uf0e7 Done]]", createPalette(theme));
		expect(plain(output)).toBe("\ue0b6\uf0e7 Done\ue0b4");
	});
});

describe("protected Markdown", () => {
	test.each([
		["inline code", "`[[Done]] → **x**`"],
		["inline code containing a backtick", "``a ` [[Done]]``"],
		["multiline inline code", "`a\n[[Done]]`"],
		["indented code", "    [[Done]]"],
		["fenced code", "```ts\n**Cause:** → [[Done]]\n```"],
		["tilde fence", "~~~\n[[Done]]\n~~~"],
		["list code", "- Example:\n\n  ```\n  [[Done]]\n  ```"],
		["quote code", "> ```\n> [[Done]]\n> ```"],
		["escaped bold", "\\*\\*not bold\\*\\*"],
		["escaped pill", "\\[[Done]]"],
		["link", "[[Done]](https://example.com/[[Failed]])"],
		["reference definition", "[ref]: https://example.com/[[Done]]"],
		["inline math", "$[[Done]]$"],
		["display math", "$$\n[[Done]]\n$$"],
		["HTML block", "<div>\n[[Done]]\n</div>"],
		["streaming code fence", "```\n[[Done]]"],
	] as const)("leaves %s unchanged", (_name, source) => {
		expect(decorate(source, palette)).toBe(source);
		expect(render(decorate(source, palette))).toBe(render(source));
	});
});

describe("prose containers", () => {
	test.each([
		"- [[Done]]", "1. 1 [[Done]]", "> [[Done]]\n> continued",
		"> > [[Done]]", "- **Fix:** [[Done]]\n  continued",
		"| State |\n| --- |\n| [[Done]] |", "[[Done]]\r\nnext", "x\t[[Done]]",
	])("draws pills in %j", source => {
		const output = decorate(source, palette);
		expect(plain(output)).not.toContain("[[Done]]");
		expect(render(output)).toContain("Done");
	});

	test.each([
		"| a \\| `[[Done]]` | [[Done]] |\n| --- | --- |",
		"| a \\| [[Passed]] `[[Done]]` | [[Done]] |\n| --- | --- |",
		"| | `[[Done]]` | [[Done]] |\n| --- | --- | --- |",
	])("keeps code literal in bounded table cells: %j", source => {
		const output = decorate(source, palette);
		expect(output).toContain("`[[Done]]`");
		expect(plain(output).replace("`[[Done]]`", "")).not.toContain("[[Done]]");
		if (source.includes("[[Passed]]")) expect(plain(output)).not.toContain("[[Passed]]");
	});

	test("decorates prose after nested code without changing the code", () => {
		const source = "- Example:\n\n  ```\n  [[Failed]]\n  ```\n\n  [[Done]]";
		const output = decorate(source, palette);
		expect(output).toContain("  ```\n  [[Failed]]\n  ```");
		expect(plain(output)).not.toContain("[[Done]]");
	});

	test("preserves line endings and tabs outside its edits", () => {
		const source = "[[Done]]\r\n\r\n\t[[Failed]]";
		const output = decorate(source, palette);
		expect(output).toContain("\r\n\r\n\t[[Failed]]");
		expect(plain(output)).toStartWith(" Done ");
	});
});

describe("labels and emphasis", () => {
	test("adds one icon to headings and leading or action labels", () => {
		const colors = createPalette(theme);
		expect(plain(decorate("## Finding", colors))).toBe("## \uf002 Finding");
		expect(plain(decorate("- **Fix:** x", colors))).toBe("- **\uf0ad Fix:** x");
		expect(plain(decorate("x **Check:** y", colors))).toBe("x **\uf046 Check:** y");
		expect(plain(decorate("**Next:** go", colors))).toBe("**\uf061 Next:** go");
	});

	test("colors bold prose on both sides of code without coloring code", () => {
		const output = decorate("**a `x` b**", palette);
		expect(output).toContain(palette.bold("a "));
		expect(output).toContain("`x`");
		expect(output).toContain(palette.bold(" b"));
		expect(render(output)).toContain("a x b");
	});

	test("leaves incomplete bold literal until the closing delimiter arrives", () => {
		expect(decorate("**anchor", palette)).toBe("**anchor");
		expect(decorate("**anchor**", palette)).toContain(palette.bold("anchor"));
	});

	test("colors marks and tree connectors in prose", () => {
		const source = "a → b ✓ c ✗\n├── x\n└── y";
		const output = decorate(source, palette);
		expect(plain(output)).toBe(source);
		for (const mark of ["→", "✓", "✗", "├──", "└──"]) expect(output).toContain(palette.mark(mark));
	});

	test("keeps bold weight before and after pills and marks", () => {
		const output = new Markdown(
			decorate("**before [[Done]] → after**", palette), 0, 0, getMarkdownTheme(),
		).render(100).join("\n");
		for (const word of ["before", "after"]) {
			const at = output.indexOf(word);
			expect(at).toBeGreaterThanOrEqual(0);
			let bold = false;
			const sgr = new RegExp(`${String.fromCharCode(27)}\\[([\\d;]*)m`, "g");
			for (const [, parameters] of output.slice(0, at).matchAll(sgr)) {
				const codes = parameters.split(";").map(Number);
				for (let i = 0; i < codes.length; i++) {
					const code = codes[i];
					if (code === 0 || code === 22) bold = false;
					else if (code === 1) bold = true;
					else if (code === 38 || code === 48) i += codes[i + 1] === 2 ? 4 : 2;
				}
			}
			expect(bold).toBe(true);
		}
	});

	test("rebuilds the shared palette after a theme switch", async () => {
		const before = emphasize("[[Done]] **anchor**");
		await setTheme("light", false);
		try {
			const after = emphasize("[[Done]] **anchor**");
			expect(after).not.toBe(before);
			expect(plain(after)).toBe(plain(before));
		} finally {
			await setTheme("dark", false);
		}
	});
});

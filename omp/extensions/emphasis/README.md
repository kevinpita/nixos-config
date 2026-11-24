# OMP emphasis

Display-only status pills, label icons, and colored bold text for OMP releases after 19.1.1, which draw with the reactive pi-tui. The package adapts [pi-emphasis](https://github.com/johnlindquist/pi-emphasis/tree/f884b736c489944ee778ab951c7f78580f137b02). It retains the upstream MIT notice.

The extension does not add prompt instructions, call a model, or change stored messages. Code, escapes, links, images, HTML blocks, and math stay unchanged. It uses OMP's own Markdown lexer so code recognition agrees with the renderer. Unrecognized custom tokens stay unchanged.

## Use

Load the directory with `omp -e /path/to/emphasis`. Enable the native transcript hook in your OMP configuration:

```yaml
extensionRenderers:
  assistantText: true
```

Write `[[Done]]`, `[[Failed]]`, or `[[Needs you]]` in prose. Known words select their tone and icon. Synonyms and details such as `[[Passed 12/12]]` work as in pi-emphasis. Bold text takes the theme's link color. Known headings and leading bold labels get icons. The extension also colors check marks, arrows, and tree connectors.

Nerd Font symbols are on by default. Set environment variables before starting OMP:

- `OMP_EMPHASIS_ICONS=0` disables icons.
- `OMP_EMPHASIS_ROUND_CAPS=0` draws square pills.
- `OMP_EMPHASIS_COLOR` selects a valid OMP theme foreground token for bold text.

There is no guidance setting because this package never changes the prompt. In this repository, `/focus` calls the same renderer directly. The native `extensionRenderers.assistantText` setting controls only the transcript hook.

## Ownership

- `index.ts` registers the OMP assistant text hook.
- `render.ts` owns source-preserving decoration, the theme palette, and the shared `emphasize(markdown)` entry point.
- `words.ts` owns the pill vocabulary, synonyms, and icons.
- `test/render.test.ts` checks the real OMP lexer and Markdown renderer.

The directory has no runtime npm dependencies. OMP provides its SDK and lexer. Development dependencies are pinned in `bun.lock`.

The package can move to its own repository without Nix or focus-view code. Consumers can import `omp-emphasis/render` instead of the current relative path. The parent repository owns deployment and the focus integration. Nix copies their shared source directory so relative imports survive store symlinks.

## Check

```sh
bun install --frozen-lockfile --ignore-scripts
bun run check
```

The tests follow the upstream emphasis tests and OMP's Markdown tests. They cover pills, nested prose, protected code forms, original line endings, and theme changes.

No npm release has the reactive pi-tui yet, so the pinned development dependencies still have the old API and this check fails. Until the next OMP release, copy this directory into a checkout of the `oh-my-pi` revision that the flake pins, and run `bun test` on the copy.

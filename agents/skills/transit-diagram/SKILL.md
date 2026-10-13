---
name: transit-diagram
description: Draw documentation diagrams as transit-map SVG files with coloured lines, stations, and light and dark palettes. Use when adding or redrawing a diagram in a README or other repository docs.
---

Draw the diagram as a **transit map**: each path, category, or flow is a coloured line, each step or file is a station, and each destination is a terminus. Build it with [`transit.py`](transit.py) in this skill's directory so every map shares one palette, font, and dark-mode block.

## 1. Model the map

Write down the lines before any coordinates:

- **Line**: one route that a reader follows, such as an install path, a role, or a deployment target. Give each line one colour from `purple`, `green`, `blue`, `orange`, and `red`. Use `red` only for failure or discard branches.
- **Station**: a step or file on that route. Use a dashed station (`optional=True`) for optional steps.
- **Hub**: a start, an interchange where lines meet, or a terminus.
- **Branch**: a line that splits off with a cubic curve, such as `M480 90 C530 90, 530 40, 580 40`.
- **Feeder**: a short gray line for an input that joins a station, such as a feature that joins a role.
- **Link**: a dotted continuation (`kind="line link"`) for symlinks or other indirect connections.
- **Capsule**: one terminus that two parallel lines share.

The model is complete when every fact in the surrounding prose that the diagram shows maps to a line, station, hub, or terminus, and the source code confirms each one.

## 2. Lay it out

- Run lines left to right. Space lines 50 to 60 px apart, and space stations at least 140 px apart.
- Put a line's station labels on the side that faces away from its neighbouring lines. A start label can use `anchor="start"` at `x - 12`. Put terminus labels to the right at `x + 18`, as `term` text with a `note` line under them.
- Put the legend in a free corner, with one entry per line colour.
- Start with a width of about 900 to 1000 px. Set the height so that no label touches an edge.

## 3. Build and preview

Write a throwaway Python build script that imports `transit.py` (its docstring shows the API) and writes the SVG to the repository's diagram folder, or to `docs/diagrams/` if there is none. Fix every clipping warning from `Map.write`, then run:

```bash
python3 <skill directory>/transit.py preview <file.svg>
```

Look at both PNG files. The diagram is done when, in light and dark mode, no label is clipped, overlaps a line or another label, or is hard to read. Delete the build script and the preview files afterwards. The SVG is the committed source.

## 4. Embed

```html
<p align="center">
  <img src="docs/diagrams/<name>.svg" alt="<same text as the SVG title>" width="100%">
</p>
```

The `Map` title and the alt text describe every line in words, so a reader without the image gets the same facts. Keep the prose that the diagram illustrates. Several documents can embed the same SVG.

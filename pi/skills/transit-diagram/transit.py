"""Build transit-map SVG diagrams and preview them in light and dark mode.

Library use, from a throwaway build script:

    import sys; sys.path.insert(0, "<skill directory>")
    from transit import Map
    m = Map(900, 230, "Alt text that describes every line")
    m.line("M60 115 L820 115", "blue")
    m.hub(60, 115); m.stop(400, 115, "blue"); m.hub(820, 115)
    m.text(60, 148, "Start"); m.text(838, 120, "End", "start", "term")
    m.write("docs/diagrams/example.svg")

Preview use:

    python3 transit.py preview docs/diagrams/example.svg

writes <name>-light.png and <name>-dark.png to /tmp/transit-preview/.
"""

import re
import shutil
import subprocess
import sys
from pathlib import Path
from xml.sax.saxutils import escape

COLORS = {
    "purple": "#a371f7",
    "green": "#3fb950",
    "blue": "#2f81f7",
    "orange": "#fb8f44",
    "red": "#f85149",
    "gray": "#8c959f",
}

STYLE = (
    """  <style>
    text { font: 13px system-ui, -apple-system, "Segoe UI", sans-serif; fill: #1f2328; }
    .note { font-size: 11px; fill: #59636e; }
    .term { font-weight: 600; }
    .line { fill: none; stroke-width: 6; stroke-linecap: round; }
    .feeder { fill: none; stroke-width: 4; stroke-linecap: round; }
    .stop { fill: #ffffff; stroke-width: 3; }
    .hub { stroke: #1f2328; }
    .optional { stroke-dasharray: 3 3; }
    .link { stroke-dasharray: 2 10; }
"""
    + "".join(f"    .{name} {{ stroke: {color}; }}\n" for name, color in COLORS.items())
    + """    @media (prefers-color-scheme: dark) {
      text { fill: #e6edf3; }
      .note { fill: #9198a1; }
      .stop { fill: #0d1117; }
      .hub { stroke: #e6edf3; }
    }
  </style>
"""
)

# Approximate glyph widths in px, used only to warn about clipped labels.
CHAR_WIDTH = {"text": 7.2, "term": 7.9, "note": 6.1}


class Map:
    def __init__(self, width, height, title):
        self.width, self.height, self.title = width, height, title
        self.lines, self.stops, self.texts, self.extents = [], [], [], []

    def line(self, d, color, kind="line"):
        """Route path. kind: "line", "line link" (dotted symlink), or "feeder"."""
        self.lines.append(f'  <path class="{kind} {color}" d="{d}"/>')

    def feeder(self, d, x, y):
        """Thin gray branch line that starts with a dot at (x, y)."""
        self.line(d, "gray", "feeder")
        self.stops.append(f'  <circle cx="{x}" cy="{y}" r="5" fill="{COLORS["gray"]}"/>')

    def stop(self, x, y, color, optional=False):
        dashed = " optional" if optional else ""
        self.stops.append(f'  <circle class="stop {color}{dashed}" cx="{x}" cy="{y}" r="8"/>')

    def hub(self, x, y):
        """Start, interchange, or terminus."""
        self.stops.append(f'  <circle class="stop hub" cx="{x}" cy="{y}" r="10"/>')

    def capsule(self, x, y1, y2):
        """Terminus shared by parallel lines at y1 and y2."""
        self.stops.append(
            f'  <rect class="stop hub" x="{x - 10}" y="{y1 - 10}" width="20" height="{y2 - y1 + 20}" rx="10"/>'
        )

    def text(self, x, y, label, anchor="middle", cls=None):
        """cls: None for station labels, "term" for bold termini, "note" for small secondary text."""
        width = len(label) * CHAR_WIDTH[cls or "text"]
        left = {"start": x, "middle": x - width / 2, "end": x - width}[anchor]
        self.extents.append((label, left, left + width))
        attrs = (f' class="{cls}"' if cls else "") + (f' text-anchor="{anchor}"' if anchor != "start" else "")
        self.texts.append(f'  <text{attrs} x="{x}" y="{y}">{escape(label)}</text>')

    def legend(self, x, y, color, label):
        self.texts.append(f'  <rect x="{x}" y="{y - 7}" width="18" height="5" rx="2" fill="{COLORS[color]}"/>')
        self.text(x + 24, y, label, "start", "note")

    def svg(self):
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.width} {self.height}" role="img" aria-labelledby="title">\n'
            f'  <title id="title">{escape(self.title)}</title>\n'
            + STYLE
            + "\n"
            + "\n".join(self.lines)
            + "\n\n"
            + "\n".join(self.stops)
            + "\n\n"
            + "\n".join(self.texts)
            + "\n</svg>\n"
        )

    def write(self, path):
        for label, left, right in self.extents:
            if left < 0 or right > self.width:
                print(f"warning: '{label}' may be clipped ({left:.0f}..{right:.0f}, width {self.width})", file=sys.stderr)
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_text(self.svg())


def _rsvg():
    if shutil.which("rsvg-convert"):
        return ["rsvg-convert"]
    return ["nix", "run", "nixpkgs#librsvg", "--"]


def preview(path, out_dir="/tmp/transit-preview"):
    source = Path(path)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    svg = source.read_text()
    dark = re.sub(r"@media \(prefers-color-scheme: dark\) \{(.*?)\n    \}", r"\1", svg, flags=re.S)
    dark_source = out / f"{source.stem}-dark.svg"
    dark_source.write_text(dark)
    for name, src, background in (("light", source, "#ffffff"), ("dark", dark_source, "#0d1117")):
        png = out / f"{source.stem}-{name}.png"
        subprocess.run([*_rsvg(), "-z", "1.2", "-b", background, str(src), "-o", str(png)], check=True)
        print(png)


if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] != "preview":
        sys.exit("usage: transit.py preview <file.svg>...")
    for file in sys.argv[2:]:
        preview(file)

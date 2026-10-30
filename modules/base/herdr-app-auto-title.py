#!/usr/bin/env python3
"""Name herdr-app tabs after the work in them.

An agent tab takes the agent's terminal title. omp writes its session title
there, which its smol model makes from the first message. Other programs
name the tab after the program. A plain shell gives the tab its number again.

Only unnamed tabs (a number), tabs named after their agent program (the
"Start an agent" menu names them so), and tabs this script named are changed.
A tab that you rename stays as you named it. Rename it to "" to give it back.
"""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

POLL_SECONDS = 3
MAX_LENGTH = 40
SHELLS = {"bash", "fish", "hc", "nu", "sh", "zsh"}
# Leading spinner, status and icon glyphs, for example "π ⠴ <icon> ".
TITLE_PREFIX = re.compile(r"^(?:[^\sA-Za-z0-9]{1,3}\s+)+")
# omp's topic prefix, for example "HERDR: ".
TOPIC_PREFIX = re.compile(r"^[A-Z][A-Z0-9_-]*:\s+")


def run(*argv):
    result = subprocess.run(argv, capture_output=True, text=True, timeout=20)
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(argv)}: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout


def clean_title(title):
    title = TOPIC_PREFIX.sub("", TITLE_PREFIX.sub("", title.strip()))
    if len(title) > MAX_LENGTH:
        title = title[: MAX_LENGTH - 1].rstrip() + "…"
    return title


def wanted_name(tab):
    """The name the tab should have. "" gives it its number."""
    terminals = tab["terminals"]
    if not terminals:
        return None
    # The agent names the tab. Without one, the first terminal does.
    terminal = next((t for t in terminals if t["app"]), terminals[0])
    info = json.loads(run("hc", "get", terminal["terminal"], "--json"))
    if terminal["app"]:
        return clean_title(info.get("title") or "") or terminal["app"]
    program = (info.get("foreground") or {}).get("name") or ""
    return "" if program in SHELLS else program


def machine(tab_id):
    """Remote ids are "<machine>/<id>"."""
    return tab_id.split("/", 1)[0] if "/" in tab_id else None


def main():
    state_dir = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    state_file = state_dir / "herdr-app-auto-title.json"
    try:
        given = json.loads(state_file.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        given = {}
    saved = dict(given)

    while True:
        time.sleep(POLL_SECONDS)
        try:
            spaces = json.loads(run("herdr-app", "ls"))["spaces"]
        except Exception:
            # The window is closed.
            continue

        tabs = [tab for space in spaces for tab in space["tabs"]]
        for tab in tabs:
            current = tab["name"]
            apps = {t["app"] for t in tab["terminals"] if t["app"]}
            if not current.isdigit() and current not in apps and given.get(tab["id"]) != current:
                continue
            try:
                name = wanted_name(tab)
                if name is None or name == current or (name == "" and current.isdigit()):
                    continue
                run("herdr-app", "do", "tab.rename", json.dumps({"id": tab["id"], "name": name}))
            except Exception as error:
                print(f"{tab['id']}: {error}", file=sys.stderr, flush=True)
                continue
            if name:
                given[tab["id"]] = name
            else:
                given.pop(tab["id"], None)

        # Forget closed tabs. An offline machine's tabs are not listed, so
        # keep them until the machine is back.
        listed = {tab["id"] for tab in tabs}
        machines = {machine(tab_id) for tab_id in listed}
        for tab_id in [t for t in given if t not in listed and machine(t) in machines]:
            del given[tab_id]

        if given != saved:
            state_dir.mkdir(parents=True, exist_ok=True)
            tmp = state_file.with_suffix(".tmp")
            tmp.write_text(json.dumps(given))
            tmp.replace(state_file)
            saved = dict(given)


if __name__ == "__main__":
    main()

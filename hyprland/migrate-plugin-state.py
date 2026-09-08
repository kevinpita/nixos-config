import json
import os
from pathlib import Path
import sys
import tempfile

settings_path = Path(sys.argv[1])
state_directory = Path(sys.argv[2])

if not settings_path.exists():
    sys.exit(0)

settings = json.loads(settings_path.read_text())
for plugin, key in (("emojiLauncher", "recentEmojis"), ("timeManager", "lastMode")):
    if key not in settings.get(plugin, {}):
        continue

    state_path = state_directory / f"{plugin}_state.json"
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    if key in state:
        continue

    state[key] = settings[plugin][key]
    state_directory.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=state_directory, delete=False) as temporary:
        temporary_path = Path(temporary.name)
        try:
            json.dump(state, temporary, ensure_ascii=False, indent=2)
            temporary.write("\n")
            temporary.flush()
            os.replace(temporary_path, state_path)
        finally:
            temporary_path.unlink(missing_ok=True)

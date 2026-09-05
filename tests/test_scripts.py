import fcntl
import json
import os
import shlex
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Sandbox(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ)
        self.env.pop("BASH_ENV", None)
        self.env.update(
            HOME=str(self.root),
            XDG_RUNTIME_DIR=str(self.root / "runtime"),
            XDG_CACHE_HOME=str(self.root / "cache"),
            PATH=f"{self.bin}:{os.environ['PATH']}",
        )
        for name in ("runtime", "cache"):
            (self.root / name).mkdir()

    def command(self, name, code):
        script = self.bin / name
        script.write_text(f"#!{sys.executable}\n" + code)
        script.chmod(0o700)

    def run_script(self, script, *args, expected=0):
        result = subprocess.run(
            ["bash", str(script), *args], env=self.env,
            capture_output=True, text=True, timeout=15,
        )
        self.assertEqual(result.returncode, expected, result.stderr)
        return result


class DictationTests(Sandbox):
    script = ROOT / "modules/ui/dictate-toggle.sh"

    def setUp(self):
        super().setUp()
        self.state = self.root / "runtime/dictate"
        self.model = self.root / "model.bin"
        self.model.write_text("test model")
        self.env["DICTATE_MODEL"] = str(self.model)
        self.command("ffmpeg", '''import pathlib, signal, sys, time
signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
pathlib.Path(sys.argv[-1]).write_bytes(b"test audio")
while True:
    time.sleep(0.05)
''')
        self.command("whisper-cli", '''import os, pathlib, sys, time
if os.environ.get("TEST_TRANSCRIBE_BLOCK"):
    ready = pathlib.Path(os.environ["TEST_TRANSCRIBE_BLOCK"])
    ready.touch()
    while not ready.with_suffix(".release").exists():
        time.sleep(0.02)
base = sys.argv[sys.argv.index("-of") + 1]
pathlib.Path(base + ".txt").write_text("  Hello\\n  from the test.  \\n")
''')
        self.addCleanup(self.cancel)

    def cancel(self):
        subprocess.run(
            ["bash", str(self.script), "cancel", "--quiet"],
            env=self.env, capture_output=True, timeout=15,
        )

    def invoke(self, *args, **kwargs):
        return self.run_script(self.script, *args, "--quiet", **kwargs)

    def test_start_duplicate_stop_and_transcript(self):
        self.assertEqual(self.invoke("status").stdout.strip(), "idle")
        self.invoke("start")
        pid = (self.state / "record.pid").read_text()
        self.assertTrue(self.invoke("status").stdout.startswith("recording "))
        self.assertIn("already active", self.invoke("start", expected=1).stderr)
        self.assertEqual((self.state / "record.pid").read_text(), pid)
        self.assertEqual(self.invoke("stop", "--stdout").stdout, "Hello from the test.\n")
        self.assertEqual(self.invoke("status").stdout.strip(), "idle")

    def test_stale_pid_does_not_kill_an_unrelated_process(self):
        sleeper = subprocess.Popen(["sleep", "30"])
        self.addCleanup(sleeper.wait)
        self.addCleanup(sleeper.terminate)
        self.state.mkdir()
        (self.state / "record.pid").write_text(str(sleeper.pid))
        (self.state / "record.start-time").write_text("0")
        (self.state / "phase").write_text("recording")
        self.assertEqual(self.invoke("status").stdout.strip(), "idle")
        self.assertIsNone(sleeper.poll())
        self.assertFalse((self.state / "record.pid").exists())

    def test_cancel_respects_owner(self):
        self.invoke("start", "--owner", "first")
        self.invoke("cancel", "--owner", "second")
        self.assertTrue(self.invoke("status").stdout.startswith("recording "))
        self.invoke("cancel", "--owner", "first")
        self.assertEqual(self.invoke("status").stdout.strip(), "idle")
        self.assertFalse((self.state / "recording.wav").exists())

    def test_busy_lock_and_stale_phase(self):
        self.state.mkdir()
        (self.state / "phase").write_text("transcribing")
        with (self.state / "operation.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertEqual(self.invoke("status").stdout.strip(), "transcribing")
            self.assertIn("already running", self.invoke("start", expected=1).stderr)
        self.assertEqual(self.invoke("status").stdout.strip(), "idle")
        self.assertFalse((self.state / "phase").exists())

    def test_transcription_holds_the_operation_lock(self):
        self.invoke("start")
        ready = self.root / "transcribing"
        self.env["TEST_TRANSCRIBE_BLOCK"] = str(ready)
        process = subprocess.Popen(
            ["bash", str(self.script), "stop", "--stdout", "--quiet"],
            env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        try:
            deadline = time.monotonic() + 10
            while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(ready.exists(), "transcriber did not start")
            self.assertEqual(self.invoke("status").stdout.strip(), "transcribing")
            self.assertIn("already running", self.invoke("start", expected=1).stderr)
            ready.with_suffix(".release").touch()
            stdout, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertEqual(stdout, "Hello from the test.\n")
        finally:
            ready.with_suffix(".release").touch()
            if process.poll() is None:
                process.terminate()
            process.communicate(timeout=10)

    @unittest.skipUnless(os.environ.get("DICTATE_PACKAGE"), "Run the packaged check with Nix")
    def test_packaged_status_and_invalid_action(self):
        self.assertEqual(self.run_script(os.environ["DICTATE_PACKAGE"], "status").stdout.strip(), "idle")
        self.run_script(os.environ["DICTATE_PACKAGE"], "invalid", expected=2)


@unittest.skipUnless(os.environ.get("BROWSER_SCRIPT"), "Run the packaged check with Nix")
class BrowserTests(Sandbox):
    def setUp(self):
        super().setUp()
        self.result = self.root / "browser-result"
        (self.root / ".cache").mkdir()
        self.env.update(TEST_DAY="1", TEST_TIME="1000", BROWSER_RESULT=str(self.result))
        shell_env = self.root / "bash-env"
        shell_env.write_text('''date() {
  case "$1" in
    +%u) printf '%s\\n' "$TEST_DAY" ;;
    +%H%M) printf '%s\\n' "$TEST_TIME" ;;
    *) command date "$@" ;;
  esac
}
exec() {
  printf '%s\\n' "$@" > "$BROWSER_RESULT"
  exit 0
}
''')
        self.env["BASH_ENV"] = str(shell_env)

    def browser(self, *urls):
        self.run_script(os.environ["BROWSER_SCRIPT"], *urls)
        return self.result.read_text().splitlines()

    def test_domain_matching_and_argument_forwarding(self):
        url = "https://name@WWW.YouTube.COM:443/watch?v=a&x=1"
        self.assertEqual(self.browser(url, "https://example.org/a b"), ["brave", url, "https://example.org/a b"])
        self.assertEqual(self.browser("https://youtube.com.evil.example/")[0], "google-chrome-stable")

    def test_explicit_mode_and_brave_domain_priority(self):
        mode = self.root / ".cache/browser-mode"
        mode.write_text("brave\n")
        self.assertEqual(self.browser("https://example.org")[0], "brave")
        mode.write_text("chrome\n")
        self.env["TEST_DAY"] = "7"
        self.assertEqual(self.browser("https://example.org")[0], "google-chrome-stable")
        self.assertEqual(self.browser("https://x.com")[0], "brave")

    def test_working_hours_boundaries(self):
        for day, time_value, expected in [
            ("1", "0759", "brave"), ("1", "0800", "google-chrome-stable"),
            ("5", "1829", "google-chrome-stable"), ("5", "1830", "brave"),
            ("7", "1000", "brave"),
        ]:
            with self.subTest(day=day, time=time_value):
                self.env.update(TEST_DAY=day, TEST_TIME=time_value)
                self.assertEqual(self.browser("https://example.org")[0], expected)


class PrWorkspaceTests(Sandbox):
    script = ROOT / "modules/base/herdr-open-pr-workspaces.sh"

    def setUp(self):
        super().setUp()
        self.result = self.root / "result.json"
        self.log = self.root / "log"
        self.calls = self.root / "calls"
        self.env.update(TEST_CALLS=str(self.calls), TEST_WORKTREE=str(self.root / "worktree"))
        self.command("wt", '''import json, os, sys
if os.environ.get("TEST_WT_FAIL"):
    sys.exit(1)
print(json.dumps({"path": os.environ["TEST_WORKTREE"]}))
''')
        self.command("herdr", '''import json, os, sys
args = sys.argv[1:]
with open(os.environ["TEST_CALLS"], "a") as log:
    log.write(json.dumps(args) + "\\n")
if args[:2] == ["worktree", "list"]:
    rows = [{"path": os.environ["TEST_WORKTREE"], "open_workspace_id": "existing"}] if os.environ.get("TEST_REUSE") else []
    print(json.dumps({"result": {"worktrees": rows}}))
elif args[:2] == ["worktree", "open"]:
    print(json.dumps({"result": {"workspace": {"workspace_id": "new"}, "tab": {"tab_id": "tab"}, "root_pane": {"pane_id": "pane"}}}))
elif args[:2] == ["tab", "create"]:
    print(json.dumps({"result": {"root_pane": {"pane_id": "lazygit"}}}))
elif args[:2] == ["pane", "run"] and os.environ.get("TEST_PANE_FAIL"):
    sys.exit(1)
''')
        self.command("git", "import sys\nsys.exit(1)\n")
        self.command("gh", "raise RuntimeError('GitHub must not be called after a failed fetch')\n")

    def open_pr(self, expected=0):
        self.run_script(
            self.script, "--open-pr", str(self.root), "source", "23",
            "https://github.com/example/repo/pull/23", str(self.log), str(self.result),
            expected=expected,
        )
        return json.loads(self.result.read_text())

    def test_existing_workspace_is_reused_without_new_tabs(self):
        self.env["TEST_REUSE"] = "1"
        self.assertEqual(self.open_pr(), {"workspaceId": "existing", "outcome": "reused", "failureCount": 0})
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual([call[:2] for call in calls], [["worktree", "list"]])

    def test_worktree_failure_is_reported(self):
        self.env["TEST_WT_FAIL"] = "1"
        self.assertEqual(self.open_pr(expected=1), {"workspaceId": "", "outcome": "failed", "failureCount": 1})
        self.assertFalse(self.calls.exists())

    def test_partial_tab_setup_is_reported(self):
        self.env["TEST_PANE_FAIL"] = "1"
        self.assertEqual(self.open_pr(expected=1), {"workspaceId": "new", "outcome": "created", "failureCount": 1})

    def test_failed_fetch_stops_before_github(self):
        self.run_script(self.script, "--load-prs", str(self.root), "origin", str(self.result), str(self.log), expected=1)
        self.assertNotIn("GitHub must not", self.log.read_text())


class CommandTests(unittest.TestCase):
    def commands(self, recipe):
        result = subprocess.run(
            ["just", "--justfile", str(ROOT / "justfile"), "--dry-run", recipe],
            capture_output=True, text=True, timeout=10, check=True,
        )
        return [shlex.split(line) for line in result.stderr.splitlines() if line.startswith(("nix ", "nh "))]

    def test_switch_checks_the_same_locked_inputs_first(self):
        check = self.commands("check")
        build = self.commands("build")
        switch = self.commands("switch")
        self.assertEqual(len(check), 1)
        self.assertEqual(len(build), 1)
        self.assertEqual(len(switch), 2)
        self.assertEqual(switch[0], check[0])
        self.assertEqual(build[0][0:3], ["nh", "os", "build"])
        self.assertEqual(switch[1][0:3], ["nh", "os", "switch"])
        for command in check + build + switch:
            self.assertNotIn("--override-input", command)
            self.assertIn("--no-write-lock-file", command)
            self.assertEqual(command[-1], str(ROOT))

    def test_local_overrides_are_explicit(self):
        for recipe in ("check-local", "build-local"):
            with self.subTest(recipe=recipe):
                commands = self.commands(recipe)
                self.assertEqual(len(commands), 1)
                names = [commands[0][i + 1] for i, arg in enumerate(commands[0]) if arg == "--override-input"]
                self.assertEqual(names, ["nixos-pi", "nixos-hyprland"])

    def test_public_check_replaces_both_private_inputs(self):
        command = self.commands("check-public")[0]
        names = [command[i + 1] for i, arg in enumerate(command) if arg == "--override-input"]
        self.assertEqual(names, ["nixos-secrets", "nixos-work"])


if __name__ == "__main__":
    unittest.main()

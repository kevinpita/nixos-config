// Opens lazygit in a dialog over the tab, in the focused pane's folder and on
// its machine. The dialog closes when lazygit exits.
import { View, div } from "gpui-kit";
import { spaces, panes, focused, hc, props, openOverlay, closeOverlay, notify } from "herdr";

function location() {
  const space = spaces().find((s) => s.active), f = focused();
  const pane = f?.pane ? panes().find((p) => p.pane === f.pane) : null;
  const on = f?.pane === null ? (f.terminal?.includes("/") ? f.terminal.split("/")[0] : null) : space?.machine ?? null;
  return { cwd: pane?.cwd || f?.cwd || space?.folder, on };
}

export default class LazygitPopup extends View {
  init(_props, cx) {
    cx.spawn(async () => {
      const { cwd, on } = location();
      const args = ["run", "--bg", "--json", "--rm", "--no-parent"];
      if (cwd) args.push("--cwd", cwd);
      if (on) args.push("--on", on);
      const r = await hc([...args, "--", "lazygit"]).catch((e) => ({ code: 1, stderr: String(e) }));
      const address = r.code === 0 ? JSON.parse(r.stdout).address : null;
      if (!address) {
        closeOverlay(props().overlay);
        notify({ title: "lazygit did not start", body: r.stderr?.trim() || r.stdout, level: "error" });
        return;
      }
      // mod.json opens this launcher as a window, which does not take the
      // keyboard. So the dialog's terminal gets it, not the pane under it.
      openOverlay({
        kind: "dialog",
        modal: true,
        width: 0.8,
        height: 0.8,
        layout: { type: "block", content: { terminal: address } },
      });
      closeOverlay(props().overlay);
    });
  }

  render() {
    return div();
  }
}

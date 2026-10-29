import { readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { delimiter, join } from "node:path";

// Shows the kubectl context and namespace, as kubectl resolves them:
// the first file in KUBECONFIG that sets a value wins. kubie points
// KUBECONFIG at a per-shell file and rewrites it on `kubie ctx`/`kubie ns`.
const files = (process.env.KUBECONFIG || join(homedir(), ".kube", "config")).split(delimiter).filter(Boolean);

const mtimes = () => files.map(file => statSync(file, { throwIfNoEntry: false })?.mtimeMs ?? 0).join();

const resolve = () => {
  const configs = files.flatMap(file => {
    try {
      return [Bun.YAML.parse(readFileSync(file, "utf8")) ?? {}];
    } catch {
      return [];
    }
  });
  const name = configs.find(config => config["current-context"])?.["current-context"];
  if (!name) return undefined;
  const context = configs.flatMap(config => config.contexts ?? []).find(entry => entry?.name === name)?.context;
  return `\u{F10FE} ${name}/${context?.namespace || "default"}`;
};

export default function (pi) {
  let seen;
  const update = ctx => {
    const current = mtimes();
    if (current === seen) return;
    seen = current;
    // "z-" sorts this status after the provider and tps statuses.
    ctx.ui.setStatus("z-k8s", resolve());
  };
  pi.on("session_start", async (_event, ctx) => {
    update(ctx);
    ctx.setInterval(() => update(ctx), 2000);
  });
}

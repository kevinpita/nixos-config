import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, renameSync, rmSync } from "node:fs";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { getAgentDir, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default async function (pi: ExtensionAPI) {
  if (process.env.PI_SUBAGENT_CHILD === "1") return;
  const npmDir = join(getAgentDir(), "npm");
  const source = join(npmDir, "node_modules/pi-subagents");
  const manifest = readFileSync(join(source, "package.json"), "utf8");
  const { version } = JSON.parse(manifest);
  const patch = readFileSync("@toolPatch@");
  const digest = createHash("sha256")
    .update(manifest)
    .update(readFileSync(join(source, "src/runs/shared/child-tool-plan.ts")))
    .update(patch)
    .digest("hex");
  // Keep npm dependency resolution and stable paths for detached/resumed runs.
  // Do not delete this cache when the parent exits: children can outlive it.
  const cache = join(npmDir, ".subagent-patches");
  const target = join(cache, digest);
  mkdirSync(cache, { recursive: true });
  if (!existsSync(target)) {
    const staging = mkdtempSync(join(cache, ".staging-"));
    try {
      cpSync(source, staging, { recursive: true });
      execFileSync("@patch@", ["--batch", "--forward", "--fuzz=0", "-p1", "-i", "@toolPatch@"], {
        cwd: staging,
        stdio: "pipe",
      });
      try {
        renameSync(staging, target);
      } catch (error) {
        // Another session can publish the same complete cache first.
        if (!["EEXIST", "ENOTEMPTY"].includes((error as NodeJS.ErrnoException).code ?? "") || !existsSync(target)) throw error;
      }
    } catch (error) {
      const failure = error as Error & { stdout?: Buffer; stderr?: Buffer };
      const detail = [failure.stdout, failure.stderr].filter(Boolean).join("\n") || String(error);
      throw new Error(`Tool availability patch failed for pi-subagents ${version}. Update pi/subagents/tool-availability.patch, rebuild, and reload Pi.\n${detail}`);
    } finally {
      rmSync(staging, { recursive: true, force: true });
    }
  }
  const { default: subagents } = await import(join(target, "index.ts"));
  await subagents(pi);
}

import { join } from "node:path";
import { cpSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { execFileSync } from "node:child_process";
import {
  getAgentDir,
  type ExtensionAPI,
  type ExtensionContext,
  type ToolDefinition,
} from "@earendil-works/pi-coding-agent";

const webToolNames = new Set(["web_search", "source_check", "fetch_content", "get_search_content"]);

export default async function (pi: ExtensionAPI) {
  const npmDir = join(getAgentDir(), "npm");
  const packageDir = join(npmDir, "node_modules/@quintinshaw/pi-dynamic-workflows");
  const { version } = JSON.parse(readFileSync(join(packageDir, "package.json"), "utf8"));
  // Keep npm's parent node_modules in the copied package's resolution path.
  const scratchDir = join(npmDir, ".workflow-patches");
  mkdirSync(scratchDir, { recursive: true });
  const patchedDir = mkdtempSync(join(scratchDir, "dynamic-workflows-"));
  try {
    cpSync(packageDir, patchedDir, { recursive: true });
    execFileSync("@patch@", ["--batch", "--forward", "--fuzz=0", "-p1", "-i", "@workflowPatch@"], {
      cwd: patchedDir,
      stdio: "pipe",
    });
    copyFileSync("@webTools@", join(patchedDir, "dist/web-tools.js"));
    copyFileSync("@webToolsTypes@", join(patchedDir, "dist/web-tools.d.ts"));
  } catch (error) {
    rmSync(patchedDir, { recursive: true, force: true });
    const failure = error as Error & { stdout?: Buffer; stderr?: Buffer };
    const detail = [failure.stdout, failure.stderr].filter(Boolean).join("\n") || String(error);
    throw new Error(
      `Web tool patch failed for pi-dynamic-workflows ${version}. Update pi/dynamic-workflows/inherit-web-tools.patch in your Nix config, rebuild, and reload.\n${detail}`,
    );
  }
  process.once("exit", () => rmSync(patchedDir, { recursive: true, force: true }));
  const { default: workflows } = await import(join(patchedDir, "dist/pi-extension.js"));
  const { setWebToolProvider } = await import(join(patchedDir, "dist/web-tools.js"));

  const tools = new Map<string, ToolDefinition>();
  let context: ExtensionContext | undefined;
  pi.on("session_start", (_event, ctx) => {
    context = ctx;
  });
  pi.on("session_shutdown", () => {
    context = undefined;
  });

  const { default: webAccess } = await import(join(getAgentDir(), "npm/node_modules/pi-web-access/index.ts"));
  await webAccess({
    ...pi,
    registerTool(tool: ToolDefinition) {
      if (webToolNames.has(tool.name)) tools.set(tool.name, tool);
      pi.registerTool(tool);
    },
  });

  setWebToolProvider(() => {
    const ctx = context;
    if (!ctx) throw new Error("The host Pi session is not active");
    const sessionId = ctx.sessionManager.getSessionId();
    const inherited = [...tools.values()]
      .filter((tool) => pi.getActiveTools().includes(tool.name))
      .map((tool): ToolDefinition => ({
        ...tool,
        execute(id, params, signal, onUpdate) {
          if (context?.sessionManager.getSessionId() !== sessionId) {
            throw new Error("The host Pi session changed during this workflow");
          }
          // Workflow research runs without the interactive browser curator.
          const args = tool.name === "web_search" ? { ...params, workflow: "none" } : params;
          return tool.execute(id, args, signal, onUpdate, ctx);
        },
      }));
    const fetch = inherited.find((tool) => tool.name === "fetch_content");
    return fetch ? [...inherited, { ...fetch, name: "web_fetch" }] : inherited;
  });
  workflows(pi);
}

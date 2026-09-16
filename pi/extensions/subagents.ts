import { join } from "node:path";
import { getAgentDir, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default async function (pi: ExtensionAPI) {
  if (process.env.PI_SUBAGENT_CHILD === "1") return;
  const { default: subagents } = await import(join(getAgentDir(), "npm/node_modules/pi-subagents/index.ts"));
  await subagents(pi);
}

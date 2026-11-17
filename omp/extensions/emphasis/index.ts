import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { emphasize } from "./render.ts";

export default function emphasis(pi: ExtensionAPI): void {
	pi.registerAssistantTextRenderer(({ text }) => emphasize(text));
}

/**
 * /preset [name]: switch this session to a model preset.
 *
 * The built-in `/modelpreset switch` writes the roles of the preset into the
 * global config.yml, which this repo tracks. `/preset` puts the same roles in
 * the runtime override layer, the one that `--model` and `--smol` use, so
 * config.yml does not change. It records the preset name in the session and
 * applies the roles again when the session is resumed. omp restores the main
 * model of a resumed session itself.
 */

import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";
import { getModelPreset, getModelPresetNames } from "@oh-my-pi/pi-coding-agent/config/model-presets";
import { resolveModelRoleValue } from "@oh-my-pi/pi-coding-agent/config/model-resolver";
import { cfgModelRoles, type ModelPreset } from "@oh-my-pi/pi-coding-agent/config/model-settings";
import { settings } from "@oh-my-pi/pi-coding-agent/config/settings";
import { cfgDefaultThinkingLevel } from "@oh-my-pi/pi-coding-agent/session/settings";

const ENTRY_TYPE = "model-preset";

/** The preset `name`, or the reason why it cannot be used. */
function findPreset(name: string): ModelPreset | string {
	const lookup = getModelPreset(settings, name);
	if (lookup.kind === "found") return lookup.preset;
	return lookup.kind === "missing" ? `Preset not found: ${name}` : `Preset "${name}" is malformed: ${lookup.reason}`;
}

export default function modelPreset(pi: ExtensionAPI) {
	pi.setLabel("model-preset");

	// The preset whose roles are in the override layer of this process.
	let active: string | undefined;

	const overrideRoles = (name: string, preset: ModelPreset) => {
		cfgModelRoles.override(settings, { ...preset.modelRoles });
		cfgDefaultThinkingLevel.override(settings, preset.defaultThinkingLevel);
		active = name;
	};

	const restore = (reason: string | undefined, ctx: ExtensionContext) => {
		const recorded = ctx.sessionManager
			.getEntries()
			.findLast(entry => entry.type === "custom" && entry.customType === ENTRY_TYPE)?.data?.name;
		const preset = recorded === undefined ? undefined : findPreset(recorded);
		if (typeof preset === "object") {
			overrideRoles(recorded, preset);
			return;
		}
		if (preset !== undefined) ctx.ui.notify(`${preset}. This session uses the config.yml roles.`, "warning");
		if (active === undefined) return;
		// A new session or a fork in this process stays on the preset. Record it there too.
		if (preset === undefined && reason !== "resume") {
			pi.appendEntry(ENTRY_TYPE, { name: active });
			return;
		}
		cfgModelRoles.override(settings, undefined);
		cfgDefaultThinkingLevel.override(settings, undefined);
		active = undefined;
	};
	pi.on("session_start", (_event, ctx) => restore(undefined, ctx));
	pi.on("session_switch", (event, ctx) => restore(event.reason, ctx));

	pi.registerCommand("preset", {
		description: "Switch this session to a model preset. config.yml does not change",
		handler: async (args, ctx) => {
			let name = args.trim();
			if (!name) {
				const names = getModelPresetNames(settings);
				if (names.length === 0) {
					ctx.ui.notify("No model presets saved", "warning");
					return;
				}
				name = (await ctx.ui.select("Model preset for this session", names)) ?? "";
				if (!name) return;
			}
			const preset = findPreset(name);
			if (typeof preset === "string") {
				ctx.ui.notify(preset, "error");
				return;
			}
			const selector = preset.modelRoles.default;
			const { model, thinkingLevel, explicitThinkingLevel } = resolveModelRoleValue(selector, ctx.models.list(), {
				settings,
				roleLookup: { getModelRole: role => preset.modelRoles[role] },
			});
			if (!model) {
				ctx.ui.notify(`Preset "${name}" not applied: default model ${selector ?? "(unset)"} is not available`, "error");
				return;
			}
			overrideRoles(name, preset);
			pi.appendEntry(ENTRY_TYPE, { name });
			if (!(await pi.setModel(model))) {
				ctx.ui.notify(`Preset "${name}" roles applied, but the model was not switched: no API key for ${model.provider}/${model.id}`, "error");
				return;
			}
			// setModel keeps the current level or applies the model's default. The preset decides instead.
			const level = explicitThinkingLevel ? thinkingLevel : preset.defaultThinkingLevel;
			if (level !== undefined && level !== "inherit") pi.setThinkingLevel(level);
			ctx.ui.notify(`Switched this session to preset "${name}" (${model.provider}/${model.id}${level ? ` · ${level}` : ""})`, "info");
		},
	});
}

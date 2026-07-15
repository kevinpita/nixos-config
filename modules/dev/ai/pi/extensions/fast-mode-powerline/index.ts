import { existsSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import {
  CONFIG_DIR_NAME,
  getAgentDir,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const STATUS_KEY = "pi-openai-fast-mode";
const DEFAULT_SERVICE_TIER = "priority";
const SUPPORTED_PROVIDERS = ["openai", "openai-codex"] as const;
const SUPPORTED_PROVIDER_SET = new Set<string>(SUPPORTED_PROVIDERS);

type FastTarget = {
  provider: string;
  model: string;
  serviceTier?: string;
};

type FastModeConfig = {
  enabled: boolean;
  targets: FastTarget[];
};

type ModelRef = {
  provider: string;
  id: string;
};

type ContextWithModel = Pick<ExtensionContext, "model">;
type ContextWithUi = Pick<ExtensionContext, "hasUI" | "mode" | "ui">;
type ContextWithCwd = Pick<ExtensionContext, "cwd">;

const DEFAULT_CONFIG: FastModeConfig = {
  enabled: false,
  targets: [
    { provider: "openai", model: "gpt-5.4", serviceTier: DEFAULT_SERVICE_TIER },
    { provider: "openai", model: "gpt-5.5", serviceTier: DEFAULT_SERVICE_TIER },
    { provider: "openai-codex", model: "gpt-5.4", serviceTier: DEFAULT_SERVICE_TIER },
    { provider: "openai-codex", model: "gpt-5.5", serviceTier: DEFAULT_SERVICE_TIER },
  ],
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function cloneConfig(config: FastModeConfig = DEFAULT_CONFIG): FastModeConfig {
  return {
    enabled: config.enabled,
    targets: config.targets.map((target) => ({
      provider: target.provider,
      model: target.model,
      serviceTier: target.serviceTier ?? DEFAULT_SERVICE_TIER,
    })),
  };
}

function normalizeTarget(rawTarget: unknown): FastTarget | undefined {
  if (!isRecord(rawTarget)) return undefined;

  const rawProvider = rawTarget.provider;
  const rawModel = rawTarget.model;

  if (typeof rawProvider !== "string" || typeof rawModel !== "string") {
    return undefined;
  }

  const provider = rawProvider.trim().toLowerCase();
  const model = rawModel.trim();

  if (!provider || !model || !SUPPORTED_PROVIDER_SET.has(provider)) {
    return undefined;
  }

  const rawServiceTier = rawTarget.serviceTier;
  const serviceTier =
    typeof rawServiceTier === "string" && rawServiceTier.trim()
      ? rawServiceTier.trim()
      : DEFAULT_SERVICE_TIER;

  return { provider, model, serviceTier };
}

function normalizeTargets(rawTargets: unknown): FastTarget[] | undefined {
  if (!Array.isArray(rawTargets)) return undefined;

  const normalized: FastTarget[] = [];
  const seen = new Set<string>();

  for (const rawTarget of rawTargets) {
    const target = normalizeTarget(rawTarget);
    if (!target) continue;

    const key = `${target.provider}\u0000${target.model}`;
    if (seen.has(key)) continue;

    seen.add(key);
    normalized.push(target);
  }

  return normalized;
}

function normalizeConfig(raw: unknown, fallback: FastModeConfig = DEFAULT_CONFIG): FastModeConfig {
  const safeFallback = cloneConfig(fallback);
  if (!isRecord(raw)) return safeFallback;

  return {
    enabled: typeof raw.enabled === "boolean" ? raw.enabled : safeFallback.enabled,
    targets: normalizeTargets(raw.targets) ?? safeFallback.targets,
  };
}

function parseConfigJson(json: string, fallback: FastModeConfig = DEFAULT_CONFIG): FastModeConfig {
  try {
    return normalizeConfig(JSON.parse(json), fallback);
  } catch {
    return cloneConfig(fallback);
  }
}

function getUserConfigPath(): string {
  return join(getAgentDir(), "extensions", STATUS_KEY, "config.json");
}

function getProjectConfigPath(cwd: string): string {
  return join(resolve(cwd), CONFIG_DIR_NAME, STATUS_KEY, "config.json");
}

function selectConfigPath(cwd: string): string {
  const projectConfigPath = getProjectConfigPath(cwd);
  return existsSync(projectConfigPath) ? projectConfigPath : getUserConfigPath();
}

async function loadConfigFromPath(configPath: string): Promise<FastModeConfig> {
  try {
    return parseConfigJson(await readFile(configPath, "utf8"));
  } catch {
    return cloneConfig();
  }
}

async function saveConfigToPath(configPath: string, config: FastModeConfig): Promise<void> {
  await mkdir(dirname(configPath), { recursive: true });
  await writeFile(`${configPath}`, `${JSON.stringify(normalizeConfig(config), null, 2)}\n`, "utf8");
}

function parseFastCommand(args: string, currentEnabled: boolean): boolean {
  const normalized = args.trim().toLowerCase();

  if (!normalized || normalized === "toggle") return !currentEnabled;
  if (normalized === "on") return true;
  if (normalized === "off") return false;

  throw new Error("Usage: /fast [on|off|toggle]");
}

function getFastCommandCompletions(argumentPrefix: string): { value: string; label: string }[] {
  const prefix = argumentPrefix.trim().toLowerCase();
  return ["on", "off", "toggle"]
    .filter((option) => option.startsWith(prefix))
    .map((value) => ({ value, label: value }));
}

function toModelRef(model: unknown): ModelRef | undefined {
  if (!isRecord(model)) return undefined;

  const { provider, id } = model;
  if (typeof provider !== "string" || typeof id !== "string") return undefined;
  if (!provider || !id) return undefined;

  return { provider, id };
}

function findMatchingTarget(model: ModelRef | undefined, targets: FastTarget[]): FastTarget | undefined {
  if (!model || !SUPPORTED_PROVIDER_SET.has(model.provider)) return undefined;

  return targets.find(
    (target) =>
      target.provider === model.provider &&
      target.model === model.id &&
      SUPPORTED_PROVIDER_SET.has(target.provider),
  );
}

function getFastStatus(config: FastModeConfig, model: ModelRef | undefined): string | undefined {
  return config.enabled && findMatchingTarget(model, config.targets) ? "fast" : undefined;
}

function refreshCurrentModel(ctx: ContextWithModel, currentModel: ModelRef | undefined): ModelRef | undefined {
  return toModelRef(ctx.model) ?? currentModel;
}

function notifyError(ctx: ContextWithUi, error: unknown): void {
  if (!ctx.hasUI) return;
  const message = error instanceof Error ? error.message : String(error);
  ctx.ui.notify(message, "error");
}

function updateFastStatus(ctx: ContextWithUi, config: FastModeConfig, model: ModelRef | undefined): void {
  if (!ctx.hasUI) return;

  ctx.ui.setStatus(STATUS_KEY, getFastStatus(config, model));

  if (ctx.mode === "tui") {
    ctx.ui.setWidget?.(STATUS_KEY, undefined);
  }
}

function clearFastStatus(ctx: ContextWithUi): void {
  if (!ctx.hasUI) return;

  ctx.ui.setStatus(STATUS_KEY, undefined);

  if (ctx.mode === "tui") {
    ctx.ui.setWidget?.(STATUS_KEY, undefined);
  }
}

export default function fastModePowerline(pi: ExtensionAPI): void {
  let config: FastModeConfig = cloneConfig();
  let configPath: string | undefined;
  let loadedCwd: string | undefined;
  let currentModel: ModelRef | undefined;

  async function loadForContext(ctx: ContextWithCwd): Promise<void> {
    configPath = selectConfigPath(ctx.cwd);
    loadedCwd = ctx.cwd;
    config = await loadConfigFromPath(configPath);
  }

  async function ensureLoaded(ctx: ContextWithCwd): Promise<void> {
    if (!configPath || loadedCwd !== ctx.cwd) {
      await loadForContext(ctx);
    }
  }

  async function saveCurrent(ctx: ContextWithCwd): Promise<void> {
    await ensureLoaded(ctx);

    if (!configPath) {
      throw new Error("Fast Mode config path was not resolved");
    }

    await saveConfigToPath(configPath, config);
  }

  pi.registerFlag("fast", {
    description: "Start with Fast Mode enabled",
    type: "boolean",
    default: false,
  });

  pi.registerCommand("fast", {
    description: "Toggle Fast Mode. Usage: /fast [on|off|toggle]",
    getArgumentCompletions: getFastCommandCompletions,
    handler: async (args: string, ctx: ExtensionCommandContext): Promise<void> => {
      try {
        await ensureLoaded(ctx);
        currentModel = refreshCurrentModel(ctx, currentModel);
        config.enabled = parseFastCommand(args, config.enabled);
        await saveCurrent(ctx);
        updateFastStatus(ctx, config, currentModel);
      } catch (error) {
        notifyError(ctx, error);
      }
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    try {
      currentModel = toModelRef(ctx.model);
      await loadForContext(ctx);

      if (pi.getFlag("fast") === true) {
        config.enabled = true;
        await saveCurrent(ctx);
      }

      updateFastStatus(ctx, config, currentModel);
    } catch (error) {
      notifyError(ctx, error);
    }
  });

  pi.on("model_select", (event, ctx) => {
    currentModel = toModelRef(event.model) ?? refreshCurrentModel(ctx, currentModel);
    updateFastStatus(ctx, config, currentModel);
  });

  pi.on("before_provider_request", (event, ctx) => {
    const target = findMatchingTarget(refreshCurrentModel(ctx, currentModel), config.targets);
    if (!config.enabled || !target || !isRecord(event.payload)) return undefined;

    return {
      ...event.payload,
      service_tier: target.serviceTier ?? DEFAULT_SERVICE_TIER,
    };
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    try {
      if (configPath) {
        await saveConfigToPath(configPath, config);
      }
    } catch (error) {
      notifyError(ctx, error);
    } finally {
      clearFastStatus(ctx);
    }
  });
}

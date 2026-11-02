import type { UsageLimit, UsageProvider } from "@oh-my-pi/pi-ai";
import { ProviderHttpError } from "@oh-my-pi/pi-ai/error";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { join } from "node:path";

const QUOTA_URL = "https://cloud-api.nan.builders/api/usage/quota";

export default async function (pi: ExtensionAPI) {
  const z = pi.zod;
  const tokens = z.number().int().nonnegative();
  const timestamp = z.string().refine(value => Number.isFinite(Date.parse(value)), "Invalid quota timestamp")
    .transform(value => Date.parse(value));
  const configSchema = z.object({
    providers: z.object({
      nan: z.object({
        baseUrl: z.literal("https://api.nan.builders/v1"),
        apiKey: z.string().min(1),
        models: z.array(z.object({ id: z.string() })),
      }),
    }),
  });
  const quotaSchema = z.object({
    models: z.array(z.object({
      model: z.string(),
      tokensUsed: tokens,
      cap: tokens,
      remaining: tokens,
      periodEnd: timestamp,
      windowTokensUsed: tokens.optional(),
      fullWindowTokens: tokens.optional(),
      windowHours: z.number().positive().optional(),
      windowResetsAt: timestamp.optional(),
      extraTokens: tokens.optional(),
    })),
  });
  const config = configSchema.parse(Bun.YAML.parse(
    await Bun.file(join(pi.pi.getAgentDir(), "models.yml")).text(),
  )).providers.nan;
  const modelIds = new Set(config.models.map(model => model.id));

  const usage: UsageProvider = {
    id: "nan",
    cacheVersion: 2,
    supports: params => params.provider === "nan" && params.credential.type === "api_key",
    async fetchUsage(params, ctx) {
      if (!params.credential.apiKey || params.baseUrl !== config.baseUrl) return null;
      const response = await ctx.fetch(QUOTA_URL, {
        headers: {
          Authorization: `Bearer ${params.credential.apiKey}`,
          Accept: "application/json",
          "User-Agent": "omp-nan-usage/1.0",
        },
        signal: params.signal,
      });
      if (response.status === 401) throw new ProviderHttpError("NaN quota key rejected", 401);
      // Cloudflare can return 403 for a valid key. Keep the last good report.
      if (!response.ok) throw new Error(`NaN quota request failed: HTTP ${response.status}`);
      const quota = quotaSchema.parse(await response.json());
      const limits: UsageLimit[] = [];
      for (const model of quota.models) {
        if (!modelIds.has(model.model) || model.cap === 0) continue;
        limits.push({
          id: `${model.model}:period`,
          label: model.model,
          scope: { provider: "nan", modelId: model.model, windowId: "period" },
          window: { id: "period", label: "Quota period", resetsAt: model.periodEnd },
          amount: { used: model.tokensUsed, limit: model.cap, remaining: model.remaining, unit: "tokens" },
          notes: model.extraTokens ? ["Bonus tokens are not included in this base quota."] : undefined,
        });
        if (model.windowTokensUsed !== undefined && model.fullWindowTokens && model.windowHours) {
          limits.push({
            id: `${model.model}:rolling`,
            label: model.model,
            scope: { provider: "nan", modelId: model.model, windowId: "rolling" },
            window: {
              id: "rolling",
              label: `Rolling ${model.windowHours}h`,
              durationMs: model.windowHours * 60 * 60 * 1000,
              resetsAt: model.windowResetsAt,
              resetLabel: "releases",
            },
            amount: { used: model.windowTokensUsed, limit: model.fullWindowTokens, unit: "tokens" },
          });
        }
      }
      return { provider: "nan", fetchedAt: Date.now(), limits };
    },
  };
  // Usage discovery does not read the models.yml key. Reuse it without changing inference.
  pi.registerProvider("nan", { apiKey: config.apiKey, usage });
}

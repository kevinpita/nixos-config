// Reloaded workflow managers can still refer to modules from the previous copy.
const providerKey = Symbol.for("pi:web-workflows:tool-provider");

export function setWebToolProvider(getTools) {
  globalThis[providerKey] = getTools;
}

export function createWebTools() {
  const provider = globalThis[providerKey];
  if (!provider) throw new Error("The Pi web tool bridge is not loaded");
  return provider();
}

export function createWebSearchTool() {
  return createWebTools().find((tool) => tool.name === "web_search");
}

export function createWebFetchTool() {
  return createWebTools().find((tool) => tool.name === "web_fetch");
}

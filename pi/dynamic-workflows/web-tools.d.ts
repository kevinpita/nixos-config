import type { ToolDefinition } from "@earendil-works/pi-coding-agent";
export declare function setWebToolProvider(getTools: () => ToolDefinition[]): void;
export declare function createWebTools(): ToolDefinition[];
export declare function createWebSearchTool(): ToolDefinition | undefined;
export declare function createWebFetchTool(): ToolDefinition | undefined;

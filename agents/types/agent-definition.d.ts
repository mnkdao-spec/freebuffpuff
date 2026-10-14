// Minimal local shape for Codebuff/Freebuff agent definitions.
// The platform ships its own richer type; this file exists so `.agents/*.ts` type-checks
// standalone (the documented check is `bun run typecheck` inside `.agents/`).
// `model` is intentionally optional: omit it and the agent runs on whatever model the
// session has selected, which is what you want on Freebuff's free tier.
export type AgentDefinition = {
  id: string;
  displayName: string;
  version?: string;
  publisher?: string;
  model?: string;
  spawnerPrompt?: string;
  systemPrompt?: string;
  instructionsPrompt?: string;
  stepPrompt?: string;
  toolNames?: string[];
  spawnableAgents?: string[];
  includeMessageHistory?: boolean;
  outputMode?: 'last_message' | 'all_messages' | 'structured_output';
  inputSchema?: Record<string, { type: string; description?: string }>;
  outputSchema?: unknown;
  reasoningOptions?: { enabled?: boolean; exclude?: boolean; effort?: 'low' | 'medium' | 'high' };
  mcpServers?: Record<string, unknown>;
  handleSteps?: unknown;
};

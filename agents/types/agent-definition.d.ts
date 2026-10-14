export interface AgentDefinition {
  id: string;
  displayName: string;
  version?: string;
  includeMessageHistory?: boolean;
  outputMode?: string;
  toolNames: string[];
  spawnerPrompt?: string;
  inputSchema?: Record<string, unknown>;
  systemPrompt?: string;
  instructionsPrompt?: string;
  stepPrompt?: string;
}

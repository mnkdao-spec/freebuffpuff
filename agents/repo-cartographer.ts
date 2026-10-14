import type { AgentDefinition } from './types/agent-definition';

/**
 * Read-only orientation agent. Run it before changing anything, so the plan is based on what the
 * stack actually is rather than what the request assumes it is.
 *
 * It has no write tools: its output is a map, not a change.
 */
const definition: AgentDefinition = {
  id: 'repo-cartographer',
  displayName: 'Repo Cartographer',
  version: '1.0.0',
  // No `model` field on purpose - inherits the session model, so it works on the free tier.
  includeMessageHistory: false,
  outputMode: 'last_message',
  toolNames: ['read_files', 'code_search', 'find_files', 'run_terminal_command', 'think_deeply', 'end_turn'],
  spawnerPrompt:
    'Spawn FIRST, before planning or changing a self-hosted media stack or notes repo. Maps services, ports, mounts, config locations and where files flow. Read-only.',
  inputSchema: {
    prompt: {
      type: 'string',
      description:
        'What to map: the repo root or the specific area (compose file, service configs, scripts, vault structure), plus which questions the map should answer.',
    },
  },
  systemPrompt: `You map a system. You do not change it.

Absolute constraints:
- Read-only. Never call write_file, str_replace or run_file_change_hooks. Never run a mutating command.
- Never open a file that holds credentials (.env, *.key, *.pem, config.xml, slskd.yml with tokens).
  Report its location and which variables it is expected to define - never its contents.
- Distinguish what you OBSERVED (a file you read, a line you can cite) from what you INFER.
  Label every inference.`,
  instructionsPrompt: `Start from the compose file or the entrypoint, then follow the references.
Use code_search/find_files to find config files rather than guessing names. For every claim, name the file and
the line that supports it. Do not summarise a file you did not open.`,
  stepPrompt: `Continue mapping read-only. Use end_turn when the map is complete.`,
};

export default definition;

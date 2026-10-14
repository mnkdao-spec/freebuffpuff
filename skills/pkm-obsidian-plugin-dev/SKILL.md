---
name: pkm-obsidian-plugin-dev
description: Develop or evaluate an Obsidian plugin - TypeScript structure, vault/workspace/metadata APIs, safe vault access, Local REST API and MCP bridge, security review before running. Use when writing a plugin, connecting an agent over Local REST API, installing a community plugin/template, or reviewing plugin capabilities.
metadata:
  category: pkm
  stack: obsidian, typescript
---

# Obsidian plugin development and review

Plugins run **in-app with user permissions** (filesystem + network).

## Shape
`<vault>/.obsidian/plugins/<id>/`: `manifest.json` (**REQUIRED**: id, name, version,
minAppVersion, **author**, description, isDesktopOnly; optional authorUrl/fundingUrl;
`data.json` is runtime-written, not authored) + `main.js` (onload/onunload) + optional `styles.css`.
**`author` missing = rejected.** `versions.json` **not** required (only minAppVersion pins).
Release needs `main.js` + `manifest.json` (+`styles.css` iff used).

## Rules
1. **Vault API over Adapter/`fs`.** Background edits: `vault.process` (atomic) > `vault.modify`;
   active note: **Editor** API; frontmatter: `FileManager.processFrontMatter()`; `this.app` > global.
2. **Never delete/overwrite silently** (renames break links). 3. **Ask for less** (no undisclosed
   network; no telemetry/ads; README discloses network + out-of-vault access).
4. **`isDesktopOnly: true`** for Node APIs (mobile lacks them). 5. **Debounce** cache events.
6. **Pin `minAppVersion`** to actual usage; re-check changelog on raises.

## Agents and vaults
- **Filesystem is the real interface** (Markdown on disk; no plugin needed).
- **Official CLI** (1.12+) = vendor scripting path (needs app running).
- **Local REST API** plugin (`obsidian-local-rest-api`): HTTPS + cert **and API key** (+MCP endpoint
  with read/write/delete). **Can delete notes** — scope it, prefer read-only.
- Never expose beyond localhost; never commit keys.

## Security review before installing
DataviewJS/Templater = executable code (Templater runs system cmds). Downloaded templates =
programs with user rights. Check behavior/source/network/vault-out access. Can't read → sandbox or skip.

## Output
```
TARGET / CAPABILITY / REVIEW / RECOMMEND / BUILD (cmds + bundle) / NOT DONE (nothing installed/enabled)
```

## Never
Install/enable unapproved; grant whole-vault write when a folder suffices; call sync "backup".

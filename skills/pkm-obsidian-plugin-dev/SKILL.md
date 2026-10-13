---
name: pkm-obsidian-plugin-dev
description: Develop or evaluate an Obsidian plugin - TypeScript plugin structure, the vault/workspace/metadata APIs, safe access to vault files, the Local REST API and MCP bridge for external agents, and the security review a plugin (or template) needs before it runs. Use when writing an Obsidian plugin, when connecting an agent to a vault over the Local REST API, when asked to install a community plugin or template, or when reviewing what a vault plugin can do.
metadata:
  category: pkm
  stack: obsidian, typescript
---

# Obsidian plugin development and review

Obsidian itself is proprietary, but its plugin API is documented TypeScript, and plugins run
**in the app with your user's permissions** — including filesystem and network access.

## Plugin shape
```
<vault>/.obsidian/plugins/<id>/
  manifest.json      id, name, version, minAppVersion, description, isDesktopOnly
  main.js            bundle (entry: onload/onunload)
  styles.css         optional
src/main.ts          entry point in your dev repo
```
Core plugin APIs worth knowing: the vault object (read/create/modify/**delete** files),
the workspace (views, leaves, layout), and the metadata cache (frontmatter, links, tags,
backlinks). Register a command; add a settings tab; register a view.

Rules that keep plugins safe and maintainable:
1. **Prefer `vault.process`/`vault.create` and adapter APIs over direct `fs`** so Obsidian keeps
   its internal state consistent.
2. **Never delete or overwrite a file silently.** A plugin that renames notes breaks every link.
3. **Ask for less.** No network calls you did not tell the user about; no reading `.obsidian/`
   secrets; no telemetry by default.
4. **`isDesktopOnly: true`** if you use Node APIs — otherwise mobile installs break.
5. **Debounce.** Metadata cache events fire constantly; a per-event full-vault scan is how vaults
   get slow.
6. **Version pin** `minAppVersion` to what you actually use.

## What agents can and cannot do with a vault
- **Filesystem is the real interface.** The vault is Markdown on disk; an agent editing files
  directly is the most portable approach and needs no plugin at all.
- **Local REST API** (community plugin) exposes an authenticated local HTTP API and additionally
  documents a built-in MCP endpoint with read/write/delete, search, and targeted edits such as
  patching a heading or a frontmatter field. Separate MCP servers that talk to that plugin also
  exist. **These can delete notes** — scope them, prefer read-only, and treat write access as a
  privilege, not a convenience.
- **Never expose a local API beyond localhost**, and never put its key in a prompt, a repo, or a
  commit.

## Security review before installing anything
Dataview's JS mode and Templater's JavaScript **can execute code** — Templater can run system
commands. A template downloaded from the internet is executable code with your user's rights.
Community plugins get the same treatment as any dependency. Check: does the source match the
claimed behaviour; does it phone home; does it write outside the vault; and can you state what
it has access to. If you cannot read it, say so and recommend a sandbox or a different plugin.

## Output format
```
TARGET:      plugin/template name, source URL, version
CAPABILITY:  what it needs (vault write? network? shell? node?)
REVIEW:      findings, or "cannot verify - source not readable"
RECOMMEND:   install / do not install / install with these settings
BUILD:       for dev - the exact commands and the resulting bundle path
NOT DONE:    confirm you did not install or enable anything
```

## Never
- Install or enable a plugin or template on someone's vault without their approval.
- Grant a write-capable agent access to a whole vault when one folder would do.
- Tell a user their vault is "backed up" because it is synced. Sync propagates deletion.

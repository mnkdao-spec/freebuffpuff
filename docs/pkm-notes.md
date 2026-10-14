# Domain notes: personal knowledge base (with sources)

Verified against the official docs in **October 2026** — Obsidian ships monthly-ish, re-check the changelog.

## Version checkpoints

| Component | As verified | What it changes |
|---|---|---|
| **Obsidian** | **1.14.x** public; early access for Catalyst | **1.9 renamed legacy frontmatter** `tag`/`alias`/`cssclass` to `tags`/`aliases`/`cssclasses` (values must be **lists**). 1.12 added the **official CLI**; 1.14 Kanban views for Bases. |
| **Bases** | core since **1.9** (2025) | Table/list/card/board views over note properties from `.base` files — no plugin. Docs do **not** claim Dataview parity. |
| **Obsidian Sync** | current | E2EE **default** for new remote vaults (covers *remote*, not local). **Markdown conflicts are merged** (others: last-wins). History time-limited. `.obsidian` synced by default. |
| **Local REST API** | community plugin, active | HTTPS + locally generated cert **and API key**. Also documents an **MCP** endpoint. |
| **Syncthing** | 2.x | Conflict copies `<name>.sync-conflict-<date>-<time>-<modifiedBy>.<ext>`, **not** merged. Not a backup app — deletions propagate. |

## Plugin manifest — get this right or nothing loads

Required: `id`, `name`, `version`, `minAppVersion`, `author`, `description`, `isDesktopOnly`.
Optional: `authorUrl`, `fundingUrl`.

- **`author` is required and commonly forgotten.**
- **`versions.json` is not required.** Only pins plugin version to `minAppVersion`.
- **`data.json` is not authored** — `loadData`/`saveData` write it.
- Release needs `main.js` + `manifest.json`; `styles.css` only if used.

## Plugin API — current preferences

- Background edits: **`Vault.process`** (atomic), not `Vault.modify`.
- Active note: **Editor** API. Frontmatter: **`FileManager.processFrontMatter()`**.
- Prefer **Vault** API over Adapter; `this.app` over global `app`.
- No Node/Electron on mobile: `isDesktopOnly: true` if needed.

## Retrieval (RAG) over a personal corpus

- **Respect the embedding model's input limit.** `all-MiniLM-L6-v2` truncates at **256 tokens**.
- **Honour prompt format.** E5 expects `query:`/`passage:` prefixes, BGE a query instruction.
- **Chunking start:** ~300-500 tokens, 40-80 overlap, split on headings then paragraphs.
- **Hybrid beats pure vectors** on notes (names, IDs, quotes). Keep full-text first-class.
- **Local storage:** sqlite-vec (pre-1.0), LanceDB, local Chroma/Qdrant. `sqlite-vss` is dead — avoid.

## Sources

[Changelog](https://obsidian.md/changelog/) · [Bases](https://obsidian.md/help/bases) ·
[Manifest](https://docs.obsidian.md/Reference/Manifest) · [Plugin API](https://docs.obsidian.md/Reference/TypeScript+API/Plugin) ·
[Sync security](https://obsidian.md/help/Obsidian+Sync/Security+and+privacy) ·
[sqlite-vec](https://github.com/asg017/sqlite-vec) · [LanceDB](https://docs.lancedb.com/)

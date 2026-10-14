# Domain notes: personal knowledge base (with sources)

The facts the `pkm-*` skills rely on, so you can check them rather than trust them. Verified against
the official docs in **October 2026** — Obsidian ships monthly-ish, so re-check the changelog before
treating any of this as current.

## Version checkpoints

| Component | As verified | What it changes |
|---|---|---|
| **Obsidian** | **1.14.x** public; early access for Catalyst | **1.9 renamed the legacy frontmatter keys** `tag`/`alias`/`cssclass` to `tags`/`aliases`/`cssclasses`, and the values must be **lists**. A vault still using the singular keys silently loses those properties. 1.12 added the **official CLI**; 1.14 added Kanban views for Bases. |
| **Bases** | core feature since **1.9** (2025) | Table/list/card/board views over note properties, from a `.base` file or an embedded code block — no community plugin. Docs do **not** position it as a Dataview replacement or claim parity, so "install Dataview to get a table" is incomplete rather than wrong. |
| **Obsidian Sync** | current | E2EE is the **default** for a new remote vault, not mandatory, and it covers the *remote* vault — Obsidian states it does not encrypt your local vault. **Markdown conflicts are merged** with a text diff (other file types: last-modified-wins), which can duplicate text. History is time-limited (notes 1 month Standard / 12 Plus; attachments 2 weeks). `.obsidian` **is** synced by default; config categories are selective. |
| **Local REST API** | community plugin, id `obsidian-local-rest-api`, active | Still HTTPS with a locally generated certificate **and an API key** (only the health endpoint is open). Now also documents a built-in **MCP** endpoint. |
| **Syncthing** | 2.x | Conflict copies are still `<name>.sync-conflict-<date>-<time>-<modifiedBy>.<ext>` and are **not** merged. Its FAQ states it is not a backup application because deletions propagate. |
| **Yjs / Automerge** | Yjs 13.6.x stable (v14 still RC); Automerge 3.x | `y-leveldb` is **deprecated**; the current documented route is binary state/updates persisted via Hocuspocus (or equivalent). Storing only JSON and rebuilding a Yjs doc from it breaks update merging and can duplicate content. Newer entrant: Loro. |

## Plugin manifest — get this right or nothing loads

Required: `id`, `name`, `version`, `minAppVersion`, `author`, `description`, `isDesktopOnly`.
Optional: `authorUrl`, `fundingUrl`.

- **`author` is required and commonly forgotten** — check it first when a plugin is rejected.
- **`versions.json` is not required.** It only pins a plugin version to a `minAppVersion`, and you
  update it when you raise `minAppVersion`.
- **`data.json` is not a file you author** — `loadData`/`saveData` write it.
- Releasing: the GitHub release needs `main.js` and `manifest.json`; `styles.css` only if you use it.

## Plugin API — the current preferences

- Background file edits: **`Vault.process`** (atomic), not the older `Vault.modify`.
- Editing the *active* note: the **Editor** API, not `Vault.modify`.
- Frontmatter: **`FileManager.processFrontMatter()`**.
- Prefer the **Vault** API over the Adapter API, and `this.app` over the global `app`.
- Node/Electron APIs do not exist on mobile: set `isDesktopOnly: true` if you need them.
- Directory policies prohibit client-side telemetry and dynamically loaded ads, and require the
  README to disclose network use and any access outside the vault.

## Retrieval (RAG) over a personal corpus

- **Respect the embedding model's input limit.** `all-MiniLM-L6-v2` truncates at **256 tokens**;
  other small models differ. A chunk longer than the window is silently half-indexed.
- **Honour the model's prompt format.** E5 expects `query:`/`passage:` prefixes, BGE a query
  instruction. Index and query with the same model and settings; changing either means re-indexing.
- **Chunking starting point, not a rule:** ~300-500 tokens with 40-80 tokens of overlap, split on
  headings then paragraphs. Tune against your own questions.
- **Hybrid beats pure vectors on notes.** Current guidance still recommends combining keyword/full-text
  search with embeddings (fusion, e.g. reciprocal rank fusion) for names, IDs, paths, acronyms and
  quotes. Keep full-text as a first-class path.
- **Local storage is not the hard part.** sqlite-vec (small, dependency-free, still pre-1.0),
  LanceDB (embedded, vector + full-text), or a local Chroma/Qdrant. `sqlite-vss` is explicitly no
  longer developed — do not start there. Vector size is arithmetic: `dimensions × 4` bytes, so 50k
  vectors at 384 dims ≈ 75 MiB. Text size, not vectors, usually decides the design.

## Sources

[Changelog](https://obsidian.md/changelog/) · [Bases](https://obsidian.md/help/bases) ·
[Manifest reference](https://docs.obsidian.md/Reference/Manifest) ·
[Versions reference](https://docs.obsidian.md/Reference/Versions) ·
[Plugin guidelines](https://docs.obsidian.md/Plugins/Releasing/Plugin+guidelines) ·
[Plugin API](https://docs.obsidian.md/Reference/TypeScript+API/Plugin) ·
[Plugin security](https://obsidian.md/help/plugin-security) ·
[Developer policies](https://docs.obsidian.md/community-directory/developer-policies) ·
[Sync security](https://obsidian.md/help/Obsidian+Sync/Security+and+privacy) ·
[Sync settings](https://obsidian.md/help/sync/settings) ·
[Sync troubleshooting](https://obsidian.md/help/sync/troubleshoot) ·
[Version history](https://obsidian.md/help/sync/version-history) ·
[Obsidian CLI](https://obsidian.md/help/cli) ·
[Local REST API](https://github.com/coddingtonbear/obsidian-local-rest-api) ·
[Syncthing sync docs](https://docs.syncthing.net/users/syncing.html) ·
[Syncthing FAQ](https://docs.syncthing.net/users/faq.html) ·
[sqlite-vec](https://github.com/asg017/sqlite-vec) · [sqlite-vss status](https://github.com/asg017/sqlite-vss) ·
[LanceDB](https://docs.lancedb.com/) · [all-MiniLM-L6-v2](https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2) ·
[Sentence Transformers](https://sbert.net/examples/sentence_transformer/applications/computing-embeddings/README.html) ·
[LlamaIndex RAG strategies](https://developers.llamaindex.ai/python/framework/optimizing/basic_strategies/basic_strategies/) ·
[Hocuspocus persistence](https://tiptap.dev/docs/hocuspocus/guides/persistence) ·
[y-leveldb (deprecated)](https://github.com/yjs/y-leveldb)

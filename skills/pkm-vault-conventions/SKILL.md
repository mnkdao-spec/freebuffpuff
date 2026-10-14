---
name: pkm-vault-conventions
description: Understand and follow a personal Markdown knowledge base's structure - folders, frontmatter schema, link style, daily notes, inbox and review status - before reading or writing any note. Use before creating, editing, linking or reorganising notes in an Obsidian, Logseq or plain-Markdown vault, or when adding automation that touches a vault.
metadata:
  category: pkm
  stack: obsidian, markdown
---

# Vault conventions

Someone's memory. Read conventions first; follow exactly; impose nothing.

## Read before writing
```bash
ls -1 <vault>/ | head -30
sed -n '1,12p' <vault>/<existing note>.md
find <vault> -name '*.base' | head
```
Determine: **folder scheme** (PARA / Zettelkasten / hybrid — identify, don't assume);
**inbox**; **frontmatter** (reuse existing keys; never parallel keys);
**link style** (`[[wikilinks]]`, aliases, block refs, embeds); **naming**;
**property names** (1.9+: `tags`/`aliases`/`cssclasses` as **lists** — old singular keys silently lose data);
**query views** (**Bases** core since 1.9 renders tables/lists/cards — check what the vault uses
before adding Dataview); **tooling** (DataviewJS/Templater = executable code; editing such a note = editing code).

## Rules
- Never restructure, rename, or move notes (breaks links; history is the point).
- Follow existing metadata vocabulary exactly. Don't "improve" writing/tags/links unasked.
- No conventions yet → propose minimal (inbox + frontmatter + `status:`), not a taxonomy.

## Output
```
VAULT / CONVENTION (scheme + evidence, inbox, keys, links, naming) / TOOLING / RISKS / WHERE I WILL WRITE / UNKNOWNS
```

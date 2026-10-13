---
name: pkm-vault-conventions
description: Understand and follow the structure of a personal Markdown knowledge base - folders, frontmatter schema, link style, daily notes, inbox and review status - before reading or writing any note. Use before creating, editing, linking or reorganising notes in an Obsidian, Logseq or plain-Markdown vault, or when adding any automation that touches a vault.
metadata:
  category: pkm
  stack: obsidian, markdown
---

# Vault conventions

A vault is someone's memory. Read the conventions first, then follow them exactly; do not
impose your own structure on it.

## Read before writing
```bash
ls -1 <vault>/ | head -30                       # top-level layout
find <vault> -maxdepth 2 -name "_*" -o -name "*.md" | head -20
sed -n '1,12p' <vault>/<existing note>.md       # actual frontmatter style in use
grep -rl "^\-\-\-$" <vault> --include=*.md | head -3   # do these notes use frontmatter at all?
grep -rloE '\b(dataview|dataviewjs)\b' <vault> --include=*.md | head   # queries that may break
```
Determine, and state in your reply:
1. **Folder scheme.** Typical real-world shapes: PARA (Projects / Areas / Resources / Archive,
   organised by *actionability*), Zettelkasten (atomic notes linked by relationship, minimal
   folders), or a hybrid — PARA for active work, linked notes for durable ideas. Identify which
   this vault uses; do not assume.
2. **The inbox.** Where unprocessed captures or daily notes land.
3. **Frontmatter.** Which keys already exist, and their value style. Reuse them; do not invent
   parallel keys. A minimal, common shape:
   ```yaml
   ---
   title: <human title>
   created: YYYY-MM-DD
   updated: YYYY-MM-DD
   tags: [topic, source]
   status: draft        # draft | reviewed | permanent
   source: <url or provenance>
   confidence: low|medium|high
   ---
   ```
4. **Link style.** `[[wikilinks]]` vs Markdown links, and whether aliases, block refs (`^id`) or
   embeds (`![[...]]`) are in use.
5. **Naming.** Spaces vs hyphens, dates in filenames, capitalisation.
6. **Tooling.** Dataview/Templater queries are **code in the vault** — a note can execute
   JavaScript (and Templater can run system commands). If you edit such a note, you are editing
   code, and untrusted templates are a real risk.

## Rules
- Never restructure the vault. Propose reorganisations; do not perform them.
- Never rename or move an existing note — it breaks links, and history is the point.
- Follow the vault's existing metadata vocabulary exactly.
- Do not "improve" someone's writing, tags or links unless asked for that note specifically.
- If the vault has no conventions yet, propose the smallest one (inbox + frontmatter +
  `status:`) rather than a taxonomy.

## Output format
```
VAULT:      path, note count, top-level folders
CONVENTION: folder scheme (observed, with evidence), inbox, frontmatter keys, link style, naming
TOOLING:    dataview/templater/plugins present
RISKS:      notes containing executable queries; anything you should not touch
WHERE I WILL WRITE: the single folder, and the file naming pattern
UNKNOWNS:   conventions you could not infer
```

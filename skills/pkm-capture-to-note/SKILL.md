---
name: pkm-capture-to-note
description: Turn raw material into structured draft notes - links, articles, meeting notes, PDFs, chat threads, shell output, album or artist research - by extracting claims, separating source from interpretation, adding matching frontmatter, and staging each note in the inbox. Use when asked to capture, summarise, file, ingest or "turn this into notes", when processing a reading list, or when building a research note from a web page or document.
metadata:
  category: pkm
  stack: markdown, obsidian
---

# Capture to note

The output of this skill is **drafts in the inbox**, never finished permanent notes. A human
promotes them.

## Note shape
Follow the vault's existing keys (`pkm-vault-conventions`). Default when the vault has none:
```markdown
---
title: <the idea, not the source title>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: [topic-a, topic-b]
status: draft
source: <url or "conversation", or the file path>
confidence: low|medium|high
---

# <title>

## Source
One line: what this came from, and when you read it.

## Key points
- One claim per bullet. Concrete, no filler.

## My interpretation
Clearly separated from the source. Say explicitly when you are inferring.

## Open questions
- What you could not determine from the source.

## Related
- [[existing note]] — only link to notes that actually exist (verify with a search first)
```

## Rules
1. **Separate source from interpretation.** Do not blur them into one confident-sounding voice.
   Mark inferences as inferences, and say when a source is thin.
2. **One idea per note** where the vault is Zettelkasten-flavoured; one source-note per source
   where it is PARA-flavoured.
3. **Verify links before writing them.** `grep -ril "<note title>" <vault>` — a link to a note
   that does not exist is a broken promise in the graph.
4. **Never invent a citation.** If you cannot identify the source, write
   `source: unverified` and say so in the note. Do not fabricate an author, date or URL.
5. **Do not paste private data** into a prompt to summarise it. Work on what you were given.
6. **Never promote a draft** by changing `status: draft` to `reviewed`/`permanent`. That is a
   human act; it is the whole point of the queue.

## Procedure
1. Inventory the input: what is it, how long, is anything missing (a paywalled article, truncated
   PDF, partial thread)?
2. Extract: entities, claims, numbers, dates, contradictions with existing notes.
3. Check the vault for existing notes on the topic. Report collisions; do not merge.
4. Compose notes using the shape above.
5. Print the files and paths, then stage them in `_inbox/` if the task asked for writes.
6. List what needs a human decision: which notes are worth promoting, what should be merged,
   what the related notes should be.

## Output format
```
INPUT:      what was processed, and its completeness
CREATED:    path + one-line summary per note (verbatim content if mode = propose)
COLLISIONS: existing notes on the same topic (paths)
CONFIDENCE: per note, and why (the source's own strength, not your fluency)
LINKS:      candidate links, marked VERIFIED (exists) or PROPOSED (does not exist yet)
REVIEW:     the human's next decision, in one line
NOT DONE:   no existing note was edited, merged, renamed or promoted
```

## Anti-pattern
A note that reads like a confident summary of something you did not fully read is worse than no
note, because it will be trusted later. Say "source was truncated after section 3" instead.

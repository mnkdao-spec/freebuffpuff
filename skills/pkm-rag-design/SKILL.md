---
name: pkm-rag-design
description: Design semantic search or "chat with my notes" over a personal knowledge base - chunking, embeddings, a local-versus-hosted privacy boundary, citation back to the source note, and keeping full-text search as a first-class path. Use when asked to add semantic search, embeddings, auto-linking, related-note suggestions, or to build a retrieval pipeline over a vault, or when reviewing one that returns bad answers.
metadata:
  category: pkm
  stack: rag, embeddings, obsidian
---

# Vault retrieval design

Retrieval quality is a data problem before it is a model problem, and the privacy boundary is the
first design decision, not the last.

## Decide and document the privacy boundary first
For each stage, say where it happens:
| Stage | Local option | Hosted option |
|---|---|---|
| Chunking + index build | always local | - |
| Embeddings | local model (some vault plugins ship one, offline by default) | embedding API |
| Index storage | on disk in the vault | remote vector DB |
| Query + retrieved passages | local model | hosted LLM |

**A local index does not mean the query is local.** Embeddings may be computed on-device while
the question and the retrieved note excerpts go to a hosted model. State the whole path
explicitly, and offer a "keep these folders out of the index" list.

## Design rules
1. **Chunk by meaning, not by size.** Heading-section, then paragraph — never a whole note as one
   unit, and never a fixed 1000-character cut that splits mid-thought.
2. **Retrieve with metadata, not just vectors.** Filter by folder, tag, `status`, or date range
   before ranking. Semantic similarity and exact-text search are different tools: keep full-text
   search for names, IDs, codes and quotes, and use embeddings for "what have I written about X".
3. **Always cite the source note** (path, and ideally heading) in the answer. An uncited claim from
   a personal corpus is unverifiable, and you will not remember the provenance later.
4. **Say "not in the vault"** when retrieval finds nothing. Do not answer from model priors and
   imply it came from the notes. This is the single most damaging failure mode.
5. **Re-index deliberately.** Notes change constantly; define what triggers re-indexing and how
   long a stale index is acceptable.
6. **Never store secrets or link-log data in the index**, and exclude `.obsidian/`, attachments
   you do not want embedded (PDFs, images, voice memos), and any folder the user marks private.
7. **Evaluate before trusting.** Write ~20 real questions with known answers, run them, and report
   the hit rate. Do not ship a retrieval feature on vibes.

## Output format
```
BOUNDARY:   per stage, local or hosted, with what data crosses
CORPUS:     what is indexed, what is excluded, and why
CHUNKING:   the unit and the metadata retained per chunk
RETRIEVAL:  the rank/filter strategy, and when full-text is used instead
CITATIONS:  how a source note is surfaced in an answer
FAILURE:    behaviour when nothing is retrieved (must be "not found")
EVAL:       the question set, hit rate, and the misses
OPEN:       what is untested
```

## Anti-pattern
Semantic search that silently degrades into a plausible-sounding generator over the user's own
notes. If the system cannot show which note an answer came from, it is not a knowledge tool.

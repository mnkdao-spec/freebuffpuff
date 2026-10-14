---
name: pkm-rag-design
description: Design semantic search or "chat with my notes" over a personal knowledge base - chunking, embeddings, local-versus-hosted privacy boundary, citation to source notes, keeping full-text first-class. Use for semantic search, embeddings, auto-linking, related-note suggestions, retrieval pipelines, or reviewing bad answers.
metadata:
  category: pkm
  stack: rag, embeddings, obsidian
---

# Vault retrieval design

Quality is a data problem first; privacy boundary is decision #1, not last.

## Privacy boundary per stage
Chunking/index = always local. Embeddings: local model (vault plugin offline / Ollama /
llama.cpp) vs API. Storage: on-disk file (sqlite-vec, LanceDB) vs remote DB. Query+passages:
local vs hosted LLM. **Local index ≠ local query** — excerpts may still go hosted. State the
whole path; offer folder exclusions.

**Local storage is solved at this scale** (thousands of notes): sqlite-vec (pre-1.0;
**sqlite-vss is dead — avoid**) or LanceDB (embedded vector+full-text). 50k×384-dim float32 ≈ 75 MiB.

## Rules
1. **Chunk by meaning, respect input limits.** Headings → paragraphs; never whole-note or
   mid-thought cuts. MiniLM truncates at **256 tokens** — long chunks silently half-index.
   Start ~300-500 tokens + 40-80 overlap; tune on real questions. **Honour prompt formats**
   (E5 `query:`/`passage:`, BGE instruction); same model+settings for index and query (else re-index).
2. **Metadata-filtered retrieval** (folder/tag/status/date) + **full-text first-class**
   (names/IDs/quotes) alongside vectors.
3. **Always cite source notes** (path + heading). Uncited corpus claims are unverifiable.
4. **"Not in the vault"** on empty retrieval — never answer from priors as if from notes.
5. **Deliberate re-indexing** (trigger + acceptable staleness). 6. **No secrets/`.obsidian`/unwanted
   attachments/private folders in the index.** 7. **Evaluate** (~20 known-answer questions; report hit rate).

## Output
```
BOUNDARY / CORPUS (in + excluded + why) / CHUNKING / RETRIEVAL (rank/filter + full-text use) / CITATIONS / FAILURE (must be "not found") / EVAL / OPEN
```

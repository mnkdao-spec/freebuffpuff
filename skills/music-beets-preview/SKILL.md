---
name: music-beets-preview
description: Use beets safely on a real library - preview imports with --pretend and timid mode, list duplicates without deleting anything, understand which options actually write files, and back up the database and tags first. Use when tagging or reorganising music, when asked to import an album, when checking for duplicates, when fixing metadata in bulk, or when a beets command looks convenient but destructive.
metadata:
  category: music
  stack: beets
---

# Beets, preview-only

Beets is the most powerful tool in this stack and the easiest way to lose a library. Treat every
beets invocation as a write until you have proven otherwise.

## Rules
1. **`--pretend` first, always.** Then show the command you would run for real.
2. **Never use `-q`/quiet on ambiguous material.** Quiet mode follows a configured fallback; it is
   not review.
3. **Never `duplicates --delete`, `--merge --delete`, or any move-to-trash.** A duplicate report
   is a *review queue*, not a deletion instruction.
4. **Back up the beets database and the files' tags before a bulk operation.** The database is a
   file; tags are not, so use a manifest of old→proposed values.
5. **Don't run beets and Lidarr over the same files.** Having two tools rename or move the same
   music independently is how libraries end up with duplicate and orphaned copies. Pick one owner
   per directory, and rescan after either changes something.

## What each option actually does
| Option | Effect |
|---|---|
| `beet import --pretend` | print the plan, write nothing |
| `beet import -t` (timid) | require confirmation even for close matches |
| `beet import -C -M -W` | do **not** copy, do **not** move, do **not** write tags |
| `beet import -m` | **moves** files into the library |
| `beet move -p`, `beet update -p`, `beet write -p` | preview the corresponding write |
| `beet convert --pretend` | preview a transcode (by default originals stay) |
| `beet duplicates` | list only — safe |
| `beet config -p` | print the config path (YAML) |

Plugins that behave like writes: `fetchart` (writes a cover file), `embedart` (rewrites every
track), `lyrics` (writes with import-write enabled), `replaygain` (writes tags, can run during
import), `convert`, and `mbcollection` — which changes your **MusicBrainz account**, a remote
side effect, not a local scan.

## Procedure for a real import
1. `beet config -p` and read the configured library path and plugins. Report both.
2. `beet import --pretend <dir>` → show the candidate release and track mapping.
3. Ask the human to confirm the chosen release (edition matters: deluxe, remaster, regional).
4. Backup: the beets DB file, plus a tag manifest for the files in scope.
5. Then, and only then, the real import — one album at a time, with output captured.

## Format notes that cause rework
- FLAC uses **Vorbis comments** (repeated fields allowed). MP3 uses ID3; beets writes **ID3v2.4**
  by default, and `id3v23` exists for older players. Multi-value fields are not universally
  preserved.
- Preserve **artist credits**. `artist_credit` controls whether credited names are used instead
  of canonical ones; do not "clean up" a credit by splitting on punctuation.
- `asciify_paths` changes **paths only**, not metadata. Do not use it to normalise tags.

## Output format
```
CONFIG:      library path + enabled plugins (from `beet config -p`)
SCOPE:       directories/files in question, and the count
PREVIEW:     the --pretend output, trimmed but unedited
PROPOSED:    the exact real command, for approval
BACKUPS:     what is backed up, and where (or "NOT YET BACKED UP - do not proceed")
RISKS:       per item - loses history, rewrites tags, moves files, remote side effect
NOT DONE:    confirm nothing was written
```

## Never
- Run without `--pretend` on a directory you have not inspected.
- Let beets reorganise a Lidarr-managed library.
- Treat an exit code of 0 as proof that the metadata is correct.

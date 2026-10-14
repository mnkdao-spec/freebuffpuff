---
name: music-beets-preview
description: Use beets safely on a real library - preview imports with --pretend and timid mode, list duplicates without deleting anything, understand which options actually write files, and back up the database and tags first. Use when tagging or reorganising music, when asked to import an album, when checking for duplicates, when fixing metadata in bulk, or when a beets command looks convenient but destructive.
metadata:
  category: music
  stack: beets
---

# Beets, preview-only

Beets is the most powerful tool here and the easiest way to lose a library. Every
invocation is a write until proven otherwise.

## Rules
1. **`--pretend` first, always.** Then show the real command.
2. **Never `-q`/quiet on ambiguous material** (quiet follows a configured fallback; not review).
3. **Never `duplicates --delete`, `--merge --delete`, or move-to-trash.** Duplicates = review queue.
4. **Back up the beets DB + file tags** before bulk ops (DB is a file; tags need an old→new manifest).
5. **Don't run beets and Lidarr over the same files.** One owner per directory; rescan after changes.

## What each option does
| Option | Effect |
|---|---|
| `import --pretend` | plan only, writes nothing | `import -t` (timid) | confirm even close matches |
| `import -C -M -W` | no copy / move / tag-write | `import -m` | **moves** files |
| `move/update/write -p` | preview the write | `convert --pretend` | preview transcode |
| `duplicates` | list only — safe | `config -p` | print config path |

Write-like plugins: `fetchart` (cover file), `embedart` (rewrites tracks), `lyrics`
(with import-write), `replaygain`, `convert`, `mbcollection` (**writes your MusicBrainz account**).

## Real import procedure
1. `beet config -p` → library path + plugins. 2. `import --pretend` → candidate + mapping.
3. Human confirms release (edition matters). 4. Backup DB + tag manifest.
5. Real import — one album at a time, output captured.

## Format notes
FLAC = Vorbis comments; MP3 = ID3v2.4 default (`id3v23` for old players). Preserve
**artist credits**; `asciify_paths` affects paths only, not tags.

## Output
```
CONFIG / SCOPE / PREVIEW (trimmed, unedited) / PROPOSED (exact real cmd) / BACKUPS (or NOT YET — stop) / RISKS / NOT DONE
```

## Never
Run without `--pretend` on uninspected dirs; let beets own a Lidarr library;
treat exit 0 as proof of correct metadata.

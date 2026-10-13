# Domain notes: self-hosted music (with sources)

The facts the skills rely on, so you can check them rather than trust them. Version-sensitive: verify
against the docs for the release you actually run.

## Lidarr
- Tracks **release groups** (an album as a work); a MusicBrainz **release** is one edition. Adding an
  album by *release* MBID instead of *release-group* MBID is the most common documented mistake.
  ([FAQ](https://wiki.servarr.com/lidarr/faq))
- Automatic import wants roughly **≥80% album similarity** and **≥60% for the worst-matching track**.
  MusicBrainz recording IDs are the strongest signal; `track01.mp3` with thin tags is much harder.
  ([import troubleshooting](https://wiki.servarr.com/lidarr/import-troubleshooting))
- Where each control acts: **metadata profiles** filter release types/statuses; **quality profiles**
  set formats/upgrades/cutoff; **quality definitions** are size sanity checks (MP3/M4A/Ogg/Opus can
  fall under "Unknown" quality); **custom formats** and **release profiles** score at **grab time
  only** and cannot repair an import-time mismatch. ([settings](https://wiki.servarr.com/lidarr/settings))
- An album showing **duration 0** often means MusicBrainz lacks track lengths, which can cause search
  results to be rejected. ([FAQ](https://wiki.servarr.com/lidarr/faq))
- Stray folders must be staged **outside** the library root and brought in through Manual Import;
  copying into the library bypasses the import pipeline. ([tips](https://wiki.servarr.com/lidarr/tips-and-tricks))

## slskd / Soulseek
- **Not a native Lidarr download client on stable.** Two routes: the external **Soularr** bridge
  (own `config.ini`; Lidarr must see the slskd download folder), or a **community plugin** which needs
  a **develop/nightly** Lidarr **and** an slskd key with the **readwrite** role — and changing branches
  means a schema change with **no downgrade path**. ([Lidarr plugins](https://wiki.servarr.com/en/lidarr/plugins),
  [Soularr](https://soularr.net/), [Allquiet plugin](https://github.com/allquiet-hub/Lidarr.Plugin.Slskd))
- API is `/api/v0` with `X-API-Key` and the roles Administrator / ReadWrite / ReadOnly; config is
  `slskd.yml` in the app dir (`/app` in the official image, override with `SLSKD_CONFIG`); umask is
  `SLSKD_UMASK` — **not** the Servarr `PUID`/`PGID` convention. Default web credentials are
  `slskd`/`slskd` and must be changed; API keys over plain HTTP are discouraged by the docs.
  ([config](https://github.com/slskd/slskd/blob/master/docs/config.md))
- The **web/API port is not the Soulseek listening port**. An unforwarded listening port degrades
  search results, browsing and downloads — not just uploads. `Connection refused` is ambiguous.
  ([slskd config](https://github.com/slskd/slskd/blob/master/docs/config.md),
  [Soulseek FAQ](https://www.slsknet.org/news/faq-page))
- VPN sidecar pattern: Gluetun owns the namespace, `network_mode: service:gluetun`, `SLSKD_VPN=true`,
  provider port forwarding. ([slskd VPN guide](https://github.com/slskd/slskd/blob/master/docs/vpn.md))
- **Shares are public.** Share a dedicated folder with aliases/exclusions — never `/data` or a home
  directory. There is no universal enforced ratio, but there are etiquette expectations, and server
  abuse can end your access. Share only what you are permitted to share. (VPN changes the network
  path, not the legal position.) ([rules](https://www.slsknet.org/news/node/681))

## Navidrome
- **Tag-oriented, not folder-oriented**: album identity prefers `musicbrainz_albumid`, otherwise album
  artist + album + version/date. `PID.Album`/`PID.Track` changes require a **full scan** and the docs
  recommend backing up the database first. ([tagging](https://www.navidrome.org/docs/usage/library/tagging/),
  [persistent IDs](https://www.navidrome.org/docs/usage/configuration/persistent-ids/))
- `ARTISTS`/`ALBUMARTISTS` are multi-value entity lists; the singular tags are display text. With only
  a singular tag, Navidrome splits on ` / `, ` feat. `, ` ft. `, `; ` — hence `Scanner.ArtistSplitExceptions`
  for names like `AC/DC`.
- Compilations need a consistent Album Artist **and** the compilation flag (`TCMP=1` ID3,
  `COMPILATION=1` Vorbis). `DATE` = recording date; `YEAR` = **release** date.
- **Move first, scan, then retag, scan.** Moving and retagging at once prevents matching. Missing
  files are marked missing, not deleted, preserving ratings/play counts — do not set `Scanner.PurgeMissing`.
  Custom-tag config changes need a **full** scan. Changing artwork priority alone does not refresh
  cached art. ([FAQ](https://www.navidrome.org/docs/faq/))
- Smart playlists are **`.nsp` JSON** rule files, imported during a scan, read-only in the UI, with
  `refreshDelay` to stabilise randomised lists. ([smart playlists](https://www.navidrome.org/docs/usage/features/smart-playlists/))
- Plugins are **`.ndp`** ZIPs (`manifest.json` + `plugin.wasm`) sandboxed with Extism; **capabilities
  come from exported functions, permissions from the manifest and are admin-granted** (HTTP allowlist
  including private/loopback targets, library access, user access, cache, KV, scheduler, task queue,
  scrobbler, metadata agent, lyrics, sonic similarity). A metadata agent must return **empty/no error
  for "no match"**. ([plugins](https://www.navidrome.org/docs/usage/features/plugins/))
- Contribution rules: issue first, no duplicate PRs, branch, conventional commits, **DCO sign-off**.
  No published AI policy at the time of writing — which is not permission to skip review.
  ([CONTRIBUTING](https://github.com/navidrome/navidrome/blob/master/CONTRIBUTING.md))

## Metadata and files
- MusicBrainz: no API key for lookups, **≤1 request/second per client**, meaningful **User-Agent**,
  back off on `503`, do not rotate clients to evade throttling, cache. Use Cover Art Archive at
  `coverartarchive.org/release/<mbid>/` (and `/front`), and remember a successful download is not
  proof the art matches your edition. ([API](https://musicbrainz.org/doc/MusicBrainz_API),
  [rate limiting](https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting),
  [CAA](https://musicbrainz.org/doc/Cover_Art_Archive/API))
- MBID kinds and Picard tag names: release = `MUSICBRAINZ_ALBUMID`, release group =
  `MUSICBRAINZ_RELEASEGROUPID`, recording = `MUSICBRAINZ_TRACKID`, release track =
  `MUSICBRAINZ_RELEASETRACKID` (a different thing). ([tag mapping](https://picard-docs.musicbrainz.org/en/latest/appendices/tag_mapping.html))
- beets: `--pretend` previews; `-t` requires confirmation; `-C -M -W` suppresses copy/move/write;
  `duplicates --delete` **deletes files**; `mbcollection` writes to your **MusicBrainz account**;
  FLAC = Vorbis comments, MP3 = ID3v2.4 by default (`id3v23` for compatibility); `asciify_paths`
  affects paths only. ([CLI](https://beets.readthedocs.io/en/latest/reference/cli.html),
  [duplicates](https://beets.readthedocs.io/en/latest/plugins/duplicates.html))
- Loudness: ReplayGain and EBU R128 `R128_` tags are not synonyms; `loudgain` defaults to a
  ReplayGain 2.0-compatible target, and its maintainer notes limited time. ([loudgain](https://github.com/Moonbase59/loudgain))
- `flac -t` verifies integrity against the stored MD5 — it does **not** prove the file came from a
  lossless source. A spectrogram is a heuristic; never delete files on one. ([flac](https://xiph.org/flac/documentation_tools_flac.html))
- Library-splitting causes: inconsistent album artist, Various Artists handling, catalogue numbers
  (not globally unique), legitimately distinct deluxe/remaster/regional editions, Unicode
  composed/decomposed differences.

## Docker and storage
- Hardlinks need source and destination on the **same filesystem, seen through the same mount**;
  otherwise imports degrade to copy-and-delete. Named volumes, mergerfs branches, ZFS datasets and
  NFS/SMB exports all break or complicate this. ([TRaSH](https://trash-guides.info/File-and-Folder-Structure/Hardlinks-and-Instant-Moves/))
- `docker compose config -q` validates syntax, not runtime; `depends_on` waits for *start*, not
  readiness — use healthchecks with `condition: service_healthy`. ([Compose startup order](https://docs.docker.com/compose/how-tos/startup-order/))
- Jellyfin has **no downgrade** after a migration; Immich's database backup is **not** the photo
  library. Both are relevant if your stack grows beyond music. ([Jellyfin backup](https://jellyfin.org/docs/general/administration/backup-and-restore/),
  [Immich backup](https://docs.immich.app/administration/backup-and-restore/))

## AI tooling in this space (risk-ranked, not recommendations)
- Low risk: MusicBrainz MCP (query only), Last.fm MCP with mutations disabled, **AudioMuse-AI**
  (sonic analysis: similarity playlists, clustering), ListenBrainz/Troi (recommendation pipelines that
  can resolve against a local Subsonic server). ([mcp-musicbrainz](https://github.com/zas/mcp-musicbrainz),
  [AudioMuse-AI](https://github.com/NeptuneHub/AudioMuse-AI), [Troi](https://github.com/metabrainz/troi-recommendation-playground))
- Higher risk: Navidrome-MCP (playlists, ratings, queue, playback), mcp-arr (can add artists and
  trigger searches), slskd Telegram bots (transfer files, sweep and replace library content).
  ([Navidrome-MCP](https://github.com/Blakeem/Navidrome-MCP), [mcp-arr](https://github.com/aplaceforallmystuff/mcp-arr))
- There is **no established LLM `.nsp` generator** — which is why `.nsp` authoring is a deliberately
  included skill: it is the one AI-facing music task that touches no audio files.

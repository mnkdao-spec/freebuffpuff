# Domain notes: self-hosted music (with sources)

The facts the skills rely on. Version-sensitive: verify against the docs for the release you run.

## Version checkpoints (last verified October 2026)

| Component | As verified | What it changes |
|---|---|---|
| **Navidrome** | **0.64.x** (actively released) | **0.63.2+ rejects a `.nsp` mixing top-level `all`/`any`.** **0.64.0** disabled Extism built-in HTTP for plugins and re-encoded internal IDs — back up the DB before upgrading. Multi-library since **0.58.0**. Package format **`.ndp`**. |
| **Lidarr** | **3.x** | v3 plugin era (needs `develop`/`nightly`); .NET 8; Linux x86 dropped. **Metadata server unreliable during 2026** — prefer release-group MBID lookups. |
| **slskd** | 0.2x | API is versioned `v0`; verify routes against your own `/swagger`. |
| **Proxmox VE** | 9.2 (8.4 support ended Aug 2026) | See `proxmox-notes.md`. |

## Lidarr
- Tracks **release groups**; a MusicBrainz **release** is one edition. Adding by *release* MBID
  instead of *release-group* MBID is the most common documented mistake.
- Automatic import wants roughly **≥80% album similarity** and **≥60% for the worst-matching track**.
- **Metadata profiles** filter release types; **quality profiles** set formats/cutoff;
  **custom formats** score at **grab time only**.
- An album showing **duration 0** often means MusicBrainz lacks track lengths.
- Stage stray folders **outside** the library root; bring in via Manual Import.

## slskd / Soulseek
- **Not a native Lidarr download client on stable.** Routes: **Soularr** bridge, or a community
  plugin needing **develop/nightly** Lidarr (branch change = schema change, **no downgrade**).
- API `/api/v0` with `X-API-Key` (Administrator / ReadWrite / ReadOnly); umask is
  `SLSKD_UMASK` — **not** `PUID`/`PGID`. Default creds `slskd`/`slskd` must change.
- The **web/API port is not the Soulseek listening port**. Unforwarded listening port degrades search.
- VPN sidecar: Gluetun owns namespace, `network_mode: service:gluetun`, `SLSKD_VPN=true`.
- **Shares are public.** Share a dedicated folder — never `/data` or home. Share only what you may share.

## Navidrome
- **Tag-oriented**: album identity prefers `musicbrainz_albumid`, else album artist + album + date.
- `ARTISTS`/`ALBUMARTISTS` are multi-value; singular tags are display text.
- Compilations need consistent Album Artist **and** compilation flag. `DATE` = recording; `YEAR` = release.
- **Move first, scan, then retag, scan.** Missing files are marked missing, not deleted.
- Smart playlists are **`.nsp` JSON**, imported during scan, read-only in UI.
- Plugins are **`.ndp`** ZIPs sandboxed with Extism; **permissions from manifest, admin-granted**.

## Metadata and files
- MusicBrainz: **≤1 request/second**, meaningful **User-Agent**, back off on `503`, cache.
- MBID kinds: release = `MUSICBRAINZ_ALBUMID`, release group = `MUSICBRAINZ_RELEASEGROUPID`,
  recording = `MUSICBRAINZ_TRACKID`.
- beets: `--pretend` previews; `duplicates --delete` **deletes files**; FLAC = Vorbis, MP3 = ID3v2.4.
- `flac -t` verifies integrity against stored MD5 — not provenance.

## Docker and storage
- Hardlinks need source and destination on the **same filesystem through the same mount**.
- `docker compose config -q` validates syntax, not runtime; `depends_on` waits for *start* — use healthchecks.

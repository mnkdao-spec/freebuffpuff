# Windows 11 notes

Everything here was hardened for Windows by simulating the failure modes on Linux (backslashes in
the pack path, CRLF injection, a failing `ln`, BOM + CRLF in a skill file). Anything marked
**[tested]** has a passing check behind it; the rest is Windows behaviour this pack cannot exercise
from a Linux sandbox.

## What you need

| Tool | Why | Notes |
|---|---|---|
| **Git for Windows** | provides `bash`, `awk`, `sed`, `grep`, `tr` — the installer and all five scripts need them | use **Git Bash**, not PowerShell or cmd |
| **Node.js 18+** | runs the `local-readonly` MCP server | must be on the **Windows** PATH if Freebuff Desktop/CLI runs on Windows |
| **Python 3.9+** | four scripts and the installer's JSON checks | `python3` usually doesn't exist on Windows; the scripts now fall back to `python`. Override with `PYTHON=/c/Python312/python.exe` if needed |
| **Docker Desktop** (WSL2 backend) | the services themselves | see the hardlink warning below |

If `python` opens the Microsoft Store instead of running, you have the Store alias stub — install
from python.org and check with `where python`.

## The one rule: do not cross the WSL/Windows boundary

Freebuff on Windows **cannot execute** a `server.js` that lives on a `\\wsl$\...` path, and a
Freebuff CLI **inside** WSL cannot see `C:\...` unless it is mounted. Mixed setups fail in a way that
looks like the pack being broken.

Pick a side, per install:

- **All-Windows:** pack + project repo under `C:\Users\you\...`, Freebuff Desktop/CLI on Windows.
- **All-WSL:** pack + project repo inside the distro (`~/homelab`), Freebuff CLI installed in WSL.

If you want both surfaces, install a second copy — `./install.sh --project .` takes ten seconds.

## Install [tested]

From **Git Bash**:
```bash
cd /c/Users/you/homelab          # or your project repo
bash ./install.sh --verify       # 39 skills, 0 invalid
bash ./install.sh --project . --mcp local-readonly
```
From **PowerShell**, if you prefer to stay there:
```powershell
& "$env:ProgramFiles\Git\bin\bash.exe" -lc "cd /c/Users/you/homelab && ./install.sh --project ."
```

### Symlinks [tested]
`AGENTS.md` is created as a symlink to `knowledge.md`. Without Windows Developer Mode the installer
falls back to a **copy** and tells you. Either is fine; with a copy, re-run the installer after
editing `knowledge.md` (or enable Settings → Privacy & security → For developers → Developer Mode
for a real link).

### Line endings [tested]
`.gitattributes` forces LF for `*.sh`, `*.js`, `*.md`, `*.json`, `*.ts`. The installer now
**refuses to install** CRLF scripts rather than letting them fail later with
`\r: command not found`, and prints the fix:
```bash
git rm --cached -r . >/dev/null && git reset --hard
```
This matters if you downloaded a ZIP instead of cloning, or if a tool re-saved a file.

### Editing skills and notes in Notepad [tested]
Notepad may write a UTF-8 BOM and CRLF. The installer's validator now tolerates both — exactly as
the CLI does, whose own frontmatter pattern is `/^\uFEFF?---[ \t]*\r?\n/` — so a Notepad-saved
`SKILL.md` still validates. **VS Code is still the better habit.**

## Docker Desktop specifics

- **`PUID`/`PGID`/`UMASK` still apply** — they configure the *Linux* processes inside the containers,
  regardless of the Windows host. Same for `SLSKD_UMASK`.
- **Paths inside containers are always Linux paths.** Use one host tree mounted as `/data`:
  `C:\Users\you\media:/data`, then `/data/downloads` and `/data/media` inside every container.
- **Hardlinks are the real risk.** If your library and downloads live on a Windows drive and are
  bind-mounted into Docker Desktop, the I/O crosses the Windows↔WSL2 boundary, and same-filesystem
  hardlink semantics are not guaranteed. Lidarr's "Use Hardlinks Instead of Copy" can silently
  degrade to copy-and-delete: double the disk, double the I/O. Verify rather than assume:
  ```bash
  docker compose exec lidarr  stat -c '%d %i %n' /data/downloads/<album>/<track>.flac
  docker compose exec slskd   stat -c '%d %i %n' /downloads/<album>/<track>.flac
  ```
  (`stat -c` and the rest of the pack's commands run **inside** the Linux containers, so they are
  unaffected by your host shell.) If the device numbers differ, put the media tree on a
  **Linux-side filesystem** — inside the WSL2 distro, or on a Linux NAS — rather than `C:\`.
- **`localhost` works from Windows** thanks to port publishing, so `curl http://localhost:4533/...`
  in Git Bash reaches Navidrome. From *inside* a container, use the Compose service name as usual.

## Firewall

The `local-readonly` MCP server is a child `node.exe` process that makes outbound requests to your
LAN services. Windows Firewall may prompt on first run — allowing it is fine, but nothing here needs
**inbound** access, and no service port should ever be exposed to the internet.

## Smoke test on Windows

```bash
bash ./install.sh --verify                                   # 39 skills, 0 invalid
ls .agents/skills | wc -l                                    # 25
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | node "$(python -c "import json;print(json.load(open('.agents/mcp.json'))['mcpServers']['localReadonly']['args'][0])")" \
  | head -2
```
Expected: a `local-readonly` serverInfo line and a 10-tool list. Then run
`probe/USER-CHECKLIST.md` inside Freebuff.

## Not yet verified on real Windows

- The whole checklist in `probe/USER-CHECKLIST.md` — it needs a signed-in Freebuff session.
- Freebuff **Desktop** parity (whether it reads the same `.agents/` tree as the CLI).
- Whether Freebuff Desktop spawns the MCP server correctly with `command: "node"` on a Windows PATH.
  If `node` is not found, replace `"command": "node"` in `.agents/mcp.json` with the full path to
  `node.exe` — and re-run the installer if you move the pack.

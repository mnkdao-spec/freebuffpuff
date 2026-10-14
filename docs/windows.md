# Windows 11 notes

Everything here was hardened for Windows by simulating the failure modes on Linux (backslashes in
the pack path, CRLF injection, a failing `ln`, BOM + CRLF in a skill file). Anything marked
**[tested]** has a passing check behind it; the rest is Windows behaviour this pack cannot exercise
from a Linux sandbox.

## What you need

| Tool | Why | Notes |
|---|---|---|
| **Git for Windows** | provides `bash`, `awk`, `sed`, `grep`, `tr` | use **Git Bash**, not PowerShell or cmd |
| **Node.js 18+** | runs the `local-readonly` MCP server | must be on the **Windows** PATH if Freebuff Desktop/CLI runs on Windows |
| **Python 3.9+** | four scripts and the installer's JSON checks | `python3` usually doesn't exist on Windows; the scripts fall back to `python`. |
| **Docker Desktop** (WSL2 backend) | the services themselves | see the hardlink warning below |

## The one rule: do not cross the WSL/Windows boundary

Freebuff on Windows **cannot execute** a `server.js` that lives on a `\\wsl$\...` path, and a
Freebuff CLI **inside** WSL cannot see `C:\...` unless it is mounted. Pick a side per install:

- **All-Windows:** pack + project repo under `C:\Users\you\...`, Freebuff Desktop/CLI on Windows.
- **All-WSL:** pack + project repo inside the distro (`~/homelab`), Freebuff CLI installed in WSL.

## Install [tested]

From **Git Bash**:
```bash
cd /c/Users/you/homelab
bash ./install.sh --verify
bash ./install.sh --project . --mcp local-readonly
```

### Symlinks [tested]
`AGENTS.md` is created as a symlink to `knowledge.md`. Without Windows Developer Mode the installer
falls back to a **copy** and tells you.

### Line endings [tested]
`.gitattributes` forces LF for `*.sh`, `*.js`, `*.md`, `*.json`, `*.ts`. The installer
**refuses to install** CRLF scripts rather than letting them fail later.

### Editing skills in Notepad [tested]
Notepad may write a UTF-8 BOM and CRLF. The installer's validator tolerates both — exactly as
the CLI does — so a Notepad-saved `SKILL.md` still validates. **VS Code is still the better habit.**

## Docker Desktop specifics

- **`PUID`/`PGID`/`UMASK` still apply** — they configure the *Linux* processes inside the containers.
- **Hardlinks are the real risk.** If library and downloads live on a Windows drive bind-mounted
  into Docker Desktop, hardlink semantics are not guaranteed. Verify with
  `stat -c '%d %i %n'` inside the containers; if device numbers differ, put the media tree on a
  **Linux-side filesystem**.
- **`localhost` works from Windows** thanks to port publishing.

## Firewall

The `local-readonly` MCP server is a child `node.exe` process making outbound requests to LAN
services. Nothing here needs **inbound** access.

## Not yet verified on real Windows

- The whole checklist in `probe/USER-CHECKLIST.md` — needs a signed-in Freebuff session.
- Freebuff **Desktop** parity.
- Whether Desktop spawns the MCP server correctly with `command: "node"` on a Windows PATH.

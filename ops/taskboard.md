# Taskboard

One line per item. Keep it short enough to read cold.

| Status | Item | Next action | Notes |
|---|---|---|---|
| in flight | <e.g. Lidarr album "X" will not import> | run `.agents/skills/music-lidarr-match-doctor` and record the ranked causes | release-group MBID confirmed |
| todo | <e.g. audit library for duplicate candidates> | `bash .agents/skills/music-library-audit/scripts/lib-audit.sh <dir> --hash` | read-only |
| blocked | <e.g. change umask for imports> | need decision: shared group vs single user | affects 3 services |
| done | <what> | - | verified by `<command>` exit 0 |

Statuses: `todo` · `in flight` · `blocked` · `done`.
An item only moves to `done` when a recorded command proved it.

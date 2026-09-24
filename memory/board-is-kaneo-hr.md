---
name: board-is-kaneo-hr
description: Hexrack's cards live on Kaneo, board `HR`, through the `kaneo` MCP; Vikunja and altiplano are retired
metadata:
  type: reference
---

Hexrack's work is tracked on **Kaneo** (`kaneo.lepaux.com`), board **`HR`**, through the
**`kaneo` MCP**. It switched from Vikunja on 2026-09-24 (homelab HL-198), and card numbers
carried over: HR-1 is still HR-1.

- Resolve the board by its slug with `list_projects` (one workspace,
  `XlLKvDCbGviImqZEWeWDsXxM2p5qgdMv`). Tools take a card's cuid, never its number: find it
  with `search` (the number alone, e.g. `HR-1`, or title words alone, never both) or
  `list_tasks`.
- Columns: `to-do` → `doing` → `done`. Close with `update_task_status(done)`, after
  [[close-tracker-tasks-only-after-landing]].
- **Do not read Vikunja.** Its Hexrack project is archived and refuses writes, and the
  `altiplano` MCP that reached it is gone from every config. Each migrated comment's first
  line keeps its `[vikunja #N]` id.

**Why:** this file used to say the tracker's MCP was named `altiplano`. Since the switch,
that advice would send a session to a retired server, or to a board that no longer takes
writes.

**How to apply:** use the `kaneo` tools. If they are missing, run `claude mcp list` in the
directory the session was launched from. The workspace's `.mcp.json` provides kaneo, and MCP
tools only register at session start, so a server added mid-session needs a restart.

---
name: vikunja-mcp-is-named-altiplano
description: The Vikunja MCP server is registered as "altiplano" — searching for "vikunja" finds nothing
metadata:
  type: reference
---

The Vikunja MCP server for this account is registered under the name `altiplano`
(uvx package `altiplano`, env `VIKUNJA_URL` / `VIKUNJA_API_TOKEN`, instance
https://vikunja.lepaux.com). Searching the tool registry or MCP config for
"vikunja" returns nothing and looks like it is not installed.

It was originally project-scoped to `homelab-workspace` and `mako-workspace`
only; it is now also added at user scope so it loads in every project. Writing
tasks needs `VIKUNJA_MCP_ALLOW_WRITE=true`.

**Why:** a search for the product name gives a confident false negative, and the
obvious conclusion ("no Vikunja MCP is configured") is wrong.

**How to apply:** look for `altiplano`, not `vikunja`. MCP tools register at
session start, so a server added mid-session is unusable until Claude Code is
restarted — `claude mcp list` will show it as connected while its tools are still
absent from the session.

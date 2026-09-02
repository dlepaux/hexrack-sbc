---
name: close-tracker-tasks-only-after-landing
description: Close a Vikunja task when the work has actually landed and CI is green, not when the code is written
metadata:
  type: feedback
---

Do not mark a Vikunja task done because the implementation exists. Close it when the
work has landed on `main` and the deploy is green.

**Why:** HR-1 "Add dynamic engraving" was marked done at 12:11 on 2026-09-02 and had to
be reopened the same day — only the design decision and its CAD prerequisite had landed;
no configurator field, no worker, no wasm existed. The task's own description carries that
correction, which is how the mistake became visible at all. A task closed on "the code is
written" hides remaining work behind a green checkbox, and on this repo the gap between
written and shipped is a 7-minute Actions run that regenerates 131 STLs and can fail.

**How to apply:** after committing, push and watch the run (`gh run watch <id>
--exit-status`). Comment the commit SHA and the run id on the task while it builds, then
set `done` only once it succeeds. If it fails, the task was never done. Uncommitted work
on a feature branch is not done either, however well tested.

Related: [[vikunja-mcp-is-named-altiplano]].

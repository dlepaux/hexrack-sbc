---
name: vscode-local-history-recovers-uncommitted-files
description: Files never committed to git are often recoverable from VS Code's local history; also, hexrack-sbc descends from raspberry-pi-mini-rack
metadata:
  type: reference
---

When a file is "missing from git history", check VS Code's local history before
concluding it is gone: `~/Library/Application Support/Code/User/History/<hash>/`.
Each folder holds an `entries.json` naming the original `resource` URI plus every
saved revision. Search it with
`grep -rho '"resource":"[^"]*"' ~/Library/Application\ Support/Code/User/History/*/entries.json | grep -i <name>`.

**Why:** `cad/setup.scad` was searched for across all 34 commits, the reflog, every
dangling object and the sibling repos of `3d-print/`, and was absent from all of
them — because it had never lived in this repo. It belonged to
`WebServer/raspberry-pi-mini-rack`, this project's **ancestor**, and only its
`config.scad` reference survived the fork. Sibling copies existed in
`raspberry-pi-mini-rack2` and `megafan-200/scad/`. All three working copies are
deleted; VS Code local history held 33, 1 and 14 revisions respectively.

**How to apply:** Search git history AND VS Code local history before telling the
user a file is unrecoverable — and search by filename across all their projects, not
just the current repo, since these CAD projects share lineage and copy files between
each other. hexrack-sbc's CAD conventions (`preset_*` vectors, `get_natural_board_*`,
`get_board_rotation`) all originate in raspberry-pi-mini-rack, so its history is the
place to look for the intent behind an unexplained hexrack convention.

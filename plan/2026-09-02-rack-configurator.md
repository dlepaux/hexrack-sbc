# Rack configurator — design and backlog

Status: approved 2026-09-02. Target: replace the flat parts gallery with a rack planner.

## The problem

The site renders **61 manifest parts** as one flat gallery, **52 of them mutually exclusive
alternates** that differ only by a small pill. That is a 61-way choice standing in for what is
really five choices of two to four options each.

Worse, the choice a user actually has to get right — which dovetail variant of Back Bottom pairs
with which variant of Back Face — is enforced today only by prose in a manifest group description.

## The bet

**The user lays out a rack; every join derives itself.**

Cases tile as a honeycomb. If the user places units on a hex grid, adjacency determines everything:
which faces carry rails, which carry grooves, and which units need feet. The user never picks
`top-left` versus `bottom-right`. And because one derived female set feeds both Back Bottom and Back
Face, the pairing constraint becomes structurally impossible to violate rather than merely documented.

## Verified geometry

Confirmed against STL bounding boxes, not just source reading.

- **Flat-top hexagon.** `body-face.stl` spans X 0…150.00 (vertex to vertex) and Z 0…129.90
  (flat to flat) = `150·cos30`. Vertices sit left and right; top and bottom edges are horizontal.
- **Six faces, three mating axes:** `top↔bottom`, `top-right↔bottom-left`, `top-left↔bottom-right`
  (`cad/components/dovetails.scad:53-73`).
- **Grid pitch:** (0, ±129.90) vertically; (±112.5, ±64.95) diagonally. 112.5 = ¾ × 150, the
  standard flat-top column pitch.
- **Axial coordinates**, flat-top, with `x = 1.5R·q`, `y = √3R·(r + q/2)`:

  | direction | (dq, dr) | this face | neighbour face | gender |
  |---|---|---|---|---|
  | N  | (0,−1)  | `top`          | `bottom`       | male |
  | NE | (+1,−1) | `top-right`    | `bottom-left`  | male |
  | NW | (−1, 0) | `top-left`     | `bottom-right` | male |
  | S  | (0,+1)  | `bottom`       | `top`          | female |
  | SW | (−1,+1) | `bottom-left`  | `top-right`    | female |
  | SE | (+1, 0) | `bottom-right` | `top-left`     | female |

- **Male rails** are unioned onto Back Top (`back-top.scad:76-83`); **female grooves** are
  subtracted from Back Bottom (`back-bottom.scad:62-67`) **and** Back Face
  (`back-face.scad:147-153`). No printable part carries both genders.
- **Feet bridge a half-column offset** — they are not "the bottom unit's stand".
  `showcase.scad:38-41` imports `body-feet.stl` only under the half-offset Rock 5B+ at
  `z = body_height/2`, and under neither on-grid Pi5 — including the one resting on the ground.
  A ground unit in the lowest column rests on its own 75 mm flat bottom edge and needs nothing.
  `body-feet.stl` spans Z −64.948…+1.00 and half a case height is 64.952, so the foot drops
  exactly the offset it has to bridge (Δ = 0.004 mm). `adjustement = 4.79` (`feet.scad:16`) is the
  calibration constant that lands the trunk on the floor plane — **not** a magic number to tidy away.

  Rule: ground units are those with no S neighbour; `zmin` = the lowest ground unit's z; a ground
  unit needs feet **iff** `z > zmin`. A ground unit more than one half-step above `zmin` is a layout
  the existing foot cannot reach — warn, never silently emit feet.

  (The trunk is centred at x = 77.88, not 75, so it leans right. Only matters for collision checks.)
- **Assembly Y offsets** for client-side composition (`bodyAssembly_space = 0`):
  Dust 0, Face 0, Fan 6.4, Back Bottom 37.4, Back Top 37.4, Back Face 152.4.
  Assembled case depth is 155.4 mm.

## Measured cost

Rendered on OpenSCAD 2026.01.25 with the Manifold backend.

| pattern | face (2 mm) | back-face (3 mm) |
|---|---|---|
| voronoi | 2 s · 2.8k tris · 143 KB | 1 s · 4.2k tris · 211 KB |
| triangles | 2 s · 17.8k tris · 889 KB | 2 s · 17.1k tris · 854 KB |
| grid | 2 s · 11.9k tris · 594 KB | 3 s · 12.6k tris · 628 KB |
| **gyroid** | **79 s · 1,520,620 tris · 76 MB** | **assertion failure** |

Payload today: 26 MB over 64 STLs; CI builds them in 94 s.
Per case: 7.6 MB, of which `body-feet.stl` is 7.05 MB (147,952 of 159,464 triangles).
`showcase.stl` is 8.95 MB and loads unconditionally in the hero on every page view — the single
largest per-visitor cost, ahead of feet.

## The gyroid constraint

`gyroidCutter()` stacks 2D prism slices and solves the strand in closed form. That solution exists
only while `|sin(phase)| ≤ √½`, hence the assert at `vent-patterns.scad:175`:
`|phase| + sweep/2 ≤ 45`. With `phase = 0` the cap is `sweep ≤ 90°` — **a quarter loop, absolutely**.
Since `sweep = thickness · 360 / period`, thickening the panel cannot buy more; it only forces
`period` up in step.

Verified numerically: margin `min(R − |C|)` over x is +0.025 at 44°, exactly 0.000000 at 45°, and
−0.025 at 46°, where no `y` satisfies the gyroid for x near 0.

The face renders today only because `face_thickness = 2` gives `sweep = 90` and the assert passes at
exactly `45 ≤ 45` — a razor's edge. The 3 mm back face sweeps 135° and fails.

**The limit belongs to the method, not to the gyroid.** Two routes to a real loop:

1. **Fold** (cheap, exact, no new tooling). The gyroid's screw symmetries map any phase back into
   the legal window. All three verified numerically to 1.4×10⁻¹⁵:

   ```
   G(x, y,  90°−z) = G(90°−y, 90°−x, z)      mirror about y=x
   G(x, y, 180°+z) = G(x+180°, y+180°, z)    translate half a period
   G(x, y, 270°−z) = G(y+90°,  x+270°, z)    mirror + translate
   ```

   A full 360° tiles as four 90° bands, each solved at `t ∈ [−45°,45°]` then placed by a rigid 2D
   transform. Offsets are lattice degrees; in mm, 90° = `period/4`.

2. **Asset** (recommended). Mesh the implicit surface offline with marching cubes, commit it under
   `cad/assets/`, `import()` and intersect — the pattern the repo already uses for
   `voronoi_svg.svg` and `noctua-92.stl`. Gives ~50–100k triangles instead of ~1M, smooth tunnel
   walls instead of a 30-step staircase, and removes the phase limit entirely. CI needs no new
   tooling because the asset is generated once and committed.

**Control surface (owner's call):** one knob — the tunnel cell size. Section depth derives from it
(`face_thickness = period` for a full loop; `face_depth = face_thickness + dust + tolerance`), so the
two can never silently disagree. Consequence: a deeper face section needs longer stack screws.

## Corrections to existing documentation

- **`readme.md:55` is wrong.** M3-16 is used nowhere. Live fasteners: **M4-50 + M4 nut traps**
  (face↔dust↔fan↔back stack), **M3-10** (back panel joins), **M5-Noctua** (fan), **M2.5-4 heat-set
  inserts** (SBC supports). M3-30 (`mounting-holes.scad:120`) is dead.
- **No print guidance exists** anywhere — no layer height, infill, orientation or support notes.

## Dead code found

- `cad/components/textover.scad` calls `preset_textover()` and `preset_board_count()`; neither
  exists. Never `use`d by any file.
- `cad/sections/body/top-supports.scad` emits geometry only under `if (show_sbc)`, which CI forces
  off. Its printable supports moved into `back-bottom.scad:135` at commit 9350b68. Renders empty.
- Five files under `cad/` are never included by anything: `lib/honeycomb.scad`, `lib/brackets.scad`,
  `components/textover.scad`, `components/rails.scad`, `components/snap-fit.scad`.
- 33 config names are never read outside `config.scad`; 26 are read nowhere at all.
- `dovetail_intercase` is **not validated** — an unrecognised face name is silently ignored and
  produces a part byte-identical to `[]`. The configurator must constrain it to the six names.

---

# Backlog

Epics are ordered by dependency. Each item is sized to be independently shippable.

## Epic 0a — Dust filter engraving (CAD) — DONE

The dust filter is a flat hex ring: outer 138.05 mm point-to-point, inner 118.19, giving an
**8.6 mm band at the flats** and a 69 mm-long top flat. It prints lying flat, so its front face is a
top surface — an ideal engraving target. Engrave the front face's top and bottom bands, not the
4 mm outer edge.

- [x] `0a.1` Delete `components/textover.scad` (dead, references removed preset fields).
- [x] `0a.2` Add `dust_label_top` / `dust_label_bottom` string params, default empty.
- [x] `0a.3` Engrave both bands on the front face, centred, depth `textover_depth`.
- [x] `0a.4` Assert the rendered text stays inside the 8.6 mm band.
- [x] `0a.5` `scripts/test-dust-label.sh` — renders with and without labels, checks bbox unchanged.
- [x] `0a.6` Decide web delivery: free-form text cannot be pre-baked. Ship blank in v1.

## Epic 0b — Gyroid rework (CAD) — DONE

- [x] `0b.1` Fold spike — symmetries verified to 1.4e-15, but superseded: even folded, the
      prism stack costs ~1M facets for a full turn. The asset does it in 52k.
- [x] `0b.2` Generate the gyroid asset offline (numpy + marching cubes), commit to `cad/assets/`.
- [x] `0b.3` Replace `gyroidCutter()` with import + intersect; retire the phase assert.
- [x] `0b.4` Single knob `face_vent_gyroid_period`; derive `face_thickness` and `face_depth`.
- [x] `0b.5` Propagate the depth change: stack screw length, dust filter fit, lip interfaces.
- [x] `0b.6` Extend `scripts/test-vent-patterns.sh` to assert a triangle-count ceiling per pattern.

## Epic 1 — Pipeline (blocks the website)

- [x] `1.1` Add the vent-pattern axis to `generate-stl.sh`. Back Face falls back to `triangles`
      when the choice is `gyroid` (it cannot carry gyroid at 3 mm, and its port exclusion zone
      already differs per board).

> **Open option — matrix size.** Crossing the vent axis into Back Face gives
> 2 boards × 2 antennas × 8 masks × 3 patterns = **96 files, ≈54 MB**, and the whole build
> ≈132 STLs / ≈76 MB. That is a build-artifact cost, not a user-bandwidth one: a rack of N units
> still downloads 7 files per unit.
>
> It could collapse to ≈34 STLs / ≈25 MB by always cutting all three female grooves and masking
> only the male rails. The asymmetry that makes this safe: an **unmatched rail is a physical
> interference**, an **unmatched groove is just an open channel on an outside edge**. The UX would
> be identical — joins still derive, only Back Top varies. Costs: visible decorative channels on
> free faces, and the `bottom` groove clips the Back Face reinforcement boss and halves the wall
> under two Back Bottom brackets.
>
> Shipping the approved derived-both model first. Revisit if the payload becomes a problem.
- [ ] `1.2` **Manifest v2**: every part carries a machine-readable `options` object, so the resolver
      never parses a filename or a human string. Add `schemaVersion`.
- [ ] `1.3` Emit the axis declarations in the manifest so the UI is driven by the build, not by
      enums hardcoded in TypeScript that drift from `config.scad`.
- [ ] `1.4` Emit assembly layout offsets and per-part triangle counts and byte sizes.
- [ ] `1.5` Extend the drift check to a **completeness check**: every combination the UI can express
      must resolve to a file that exists.
- [ ] `1.6` `scripts/test-manifest.sh`, following the existing `test-*.sh` convention.
- [ ] `1.7` Commit a small **dev fixture manifest**. `npm run dev` on a fresh clone currently renders
      ErrorState, because `public/manifest.json` and `public/stl` are gitignored and only CI mode
      populates them. The frontend cannot be developed without this.

## Epic 2 — Rack configurator (website)

Mockup approved: https://claude.ai/code/artifact/e119bfd8-b285-4149-be66-999c2d373deb

- [ ] `2.1` Hex grid model in TypeScript: axial coords, the six directions, derive male/female, and
      feet by the half-column-offset rule above (not "no neighbour below").
- [ ] `2.2` Resolver: `(config) → Part[]`, driven purely by manifest v2 options.
- [ ] `2.3` Layout editor: add, remove, select; keep the rack connected on removal.
- [ ] `2.4` Per-unit board and antennas; global vent pattern and front circle.
- [ ] `2.5` Aggregated BOM with quantities and honest total size.
- [ ] `2.6` Hardware list — corrected fasteners, per unit.
- [ ] `2.7` Zip download of the resolved set only (today's Download All ships both boards' parts).
- [ ] `2.8` URL permalink. Note the token identity holds for the 7 non-default masks only; the
      default `all` maps to the suffix-less filename and must be special-cased.
- [ ] `2.9` Keep the full gallery below the configurator.
- [ ] `2.10` Tests. The website has **none** today. Vitest + Testing Library; cover the derivation
      and the resolver first, since those are where a bug ships a wrong part.

## Epic 3 — Payload and preview

- [ ] `3.1` Drop `showcase.stl` (8.95 MB) from the hero, or replace it with a decimated LOD.
      Largest per-visitor cost on the site.
- [ ] `3.2` Decimated `body-feet-preview.stl` for the viewer; keep the full mesh for download.
- [ ] `3.3` Cache geometry by resolved filename so a rack of N units fetches each distinct file once.
- [ ] `3.4` Compose the assembled preview client-side from the resolved parts using the layout
      offsets, instead of a pre-baked assembly that cannot reflect a configuration.
- [ ] `3.5` Fix the dead cleanup and the `react-hooks/exhaustive-deps` warning in
      `stl-viewer.tsx:39`.

## Epic 4 — Documentation

- [ ] `4.1` Correct the readme hardware list.
- [ ] `4.2` Add print guidance: layer height, infill, orientation, supports per part.
- [ ] `4.3` Delete the five orphan CAD files and the dead config names, or comment why they stay.


---

# What 0a and 0b actually landed (2026-09-02)

**Engraving.** `dust_label_top` / `dust_label_bottom`, engraved into the 8.6mm band on the
dust filter's front face — the one flat outward-facing surface on the assembled case, and a
top surface in the print orientation. Empty by default, so published STLs are unchanged.
`scripts/test-dust-label.sh` (7 checks) pins the envelope, asserts material is *removed*,
and asserts the ring stays one body. `components/textover.scad` and the whole `textover_*`
block are gone — dead since the drawer was removed.

**Gyroid.** Now a meshed isosurface (`cad/assets/gyroid-tunnels.stl`, generated by
`scripts/generate-gyroid-asset.py`) instead of stacked closed-form slices.
**79s / 1,520,620 facets / 76MB → 2s / ~52,700 facets / 2.6MB**, and the quarter-turn
ceiling is gone, so the tunnels complete a full turn. It is in the build axis and on the
site; the back face still falls back to `triangles`.

Three findings worth keeping:

1. **The full turn is structural, not aesthetic.** A partial slice cuts the gyroid's
   material network into islands: 1.0 turn → 1 body, 0.7 → 3, 0.6 → 7, 0.5 → 6. The
   panel must span a whole period, which is why cell size and panel depth are one knob.
2. **`face_vent_gyroid_period` is not freely tunable.** Whether the web survives depends
   on how cells fall against the hexagon, its margin ring and the front circle, and it
   does not vary smoothly — bodies at (circle on / off): 8 → 2/1, 10 → 2/1, **11 → 1/1**,
   12 → 2/1, 13 → 11/1. Only 11 holds both. A fragmented panel renders and exports
   perfectly cleanly, so `test-vent-patterns.sh` counts bodies for every pattern × circle.
3. **Tiling a single cell was tried and rejected.** It makes a 76KB asset instead of 9.2MB,
   but marching cubes caps each cell at its own boundary and those caps do not land on the
   neighbour's, leaving the panel in 3–7 pieces at some periods and 1 at others. One
   seamless block, deliberately bought.

**Case depth grew 155.4mm → 164.3mm.** `face_depth` is now derived
(`dust_filter_depth + max(face_thickness, gyroid period) + tolerance`) and sized for the
deepest panel any pattern needs, so choosing a pattern never changes the case's depth and
units in one rack always line up.

That made the manifest's hardcoded layout offsets a liability, so `cad/layout-export.scad`
now emits them and `generate-stl.sh` reads them. `test-manifest.sh` cross-checks the
published layout against the CAD rather than against literals.

**Two bugs found on the way:** the front circle was a hardcoded 2mm slab (`face_thickness`
written twice), which became a thin disc floating over hollow tunnels once the panel was
8mm — it now spans the panel. And the back-face loop iterated *face* patterns, so gyroid
and triangles both wrote the same file, leaving the resolver two matches for one
configuration; it now iterates the back face's own distinct patterns.

Build: **134 STLs / 131 parts / 86MB / 1m53s**, all gates green.

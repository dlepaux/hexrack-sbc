# silent front: a gridless face and wing-ribbed dust rings

Date: 2026-11-27. Status: built (HR-21), awaiting a print and David's ear.

## Why

The front of the case is loud. David's observations, on the real build:

- the Noctua alone (no face, no filter) is very quiet;
- the face with the triangle grille is loud on its own;
- the filter fabric in front of the grille quiets it slightly.

The cause is how close the grille is to the fan. The triangle panel (2 mm, `face_thickness`)
sits at the back of the face section, right up against the fan section. The fan sits in front
of its 3 mm web in a 31 mm section, so its frame is about 3 mm behind the grille and the
blades about 4–5 mm behind it. Each blade crossing a flat 1.6 mm web at that distance makes a
pressure pulse. Seven-odd blades and dozens of webs together make a tone. The fabric, with
its fine and even strands, adds almost no tone of its own and breaks up some of the grille's
wake. That fits what David hears.

The fix: take the solid webs out of the fan's path, and fair the ones that have to stay so
they shed a much weaker wake.

## Goals

- A face with nothing in front of the fan bore, so the case can be as quiet as the bare fan.
- Three dust rings to pick from, all on that face:
  1. **none**: the plain ring as it is today, with the fabric glued taut across the open window;
  2. **veins**: three curved ribs, with a wing-shaped cross-section, holding the fabric flat;
  3. **voronoi**: a few large organic cells, with the same wing cross-section.
- All three are published STLs, selectable on the website like the existing axes.

## Non-goals

- Making the case deeper. David: "no deeper I like it compact." The case length stays as it is.
- Changing the back face. It is far downstream of the fan and is not the noise source.
- Measuring the noise instrumentally. The test is David's ear on a printed part.

## Anti-goals

- Any support structure that brings the tone back. If the veins or voronoi ring is clearly
  louder than **none**, the variant has failed, however good it looks.
- Fabric bowing far enough to touch the fan.
- Ribs too thin to print in PETG (under 0.8 mm, two 0.4 mm lines).

## Constraints, from the code

- `face_depth` is derived from `face_panel_thickness()` (`cad/config.scad:104-107`). The new
  mode keeps the 2 mm panel thickness, so `face_depth` and every offset after it stay the same.
- The face panel carries the two M4 bosses (d = 16, top-centre and bottom-centre, 9.25 mm in
  from the flats, `cad/components/mounting-holes.scad:12`) that hold the face to the fan
  section. They are unioned after the vent cutter, so the "open" mode must leave them standing.
  Their inner edge sits about 47.75 mm from the centre, outside the 92 mm bore.
- `face_vent_pattern` is a global axis. It also drives the back face (through
  `back_face_vent_pattern()` in config and `back_face_vent()` in `scripts/lib/variant-matrix.sh`)
  and the half-cell foot (`cad/sections/body/feet.scad:164`).
- The dust ring prints flat, front face up (`cad/sections/body/dust.scad`, label comment). Its
  depth is `dust_filter_depth` = 3.9 mm. The fabric sits in a 0.32 mm glue pocket at its back
  face, 2 mm wider than the window. The window is about 118 mm point to point (about 102 mm
  across the flats).
- The front band carries the 45° chamfer and the optional label. Ribs must not reach into the
  band.
- The dust ring is built today as a shared part with no axes (`scripts/generate-stl.sh:267`).

## Approaches considered

For the face:
- **Open vent mode, same panel depth (chosen).** A new `face_vent_pattern` value cuts the
  whole margin-inset hexagon, so only the rim and the bosses are left. Same length, same joints.
- Remove the panel and shrink `face_depth` by 2 mm. That moves the fabric 2 mm closer to the
  fan, which is the wrong direction, and shifts every part behind it. Rejected.
- Make the face deeper for more stand-off. This is the strongest acoustic lever, and David
  ruled it out.

For the fabric support (David picked all three to compare):
- **Swept veins.** Three curved ribs from the rim, meeting in front of the fan's motor hub.
  The least edge in the airflow. Because the ribs are curved, a blade crosses each one
  gradually, which smears the pulse. Expected to be the quietest supported option.
- **Sparse voronoi.** About six large cells. More organic, but roughly twice the rib length,
  and its edges are straight. Expected to be a little louder than veins.
- **None.** The fabric is glued taut over the open window. The quietest if the fabric stays
  flat.
- Rejected: supports on the face, behind the fabric. They would sit about 3 mm from the
  blades, the very spot that is loud today. Also rejected: a clamp hoop. It adds a part and a
  fit risk, and the ribs give the fabric a gluing surface anyway.

The ribs live **in the dust ring, in front of the fabric**. That puts them as far from the
fan as the compact case allows (their back face is about 5.5 mm from the fan frame, against
the grille's 3 mm today), and the fabric smooths out their wakes before they reach the blades.

## Design

### Face: `face_vent_pattern = "open"`

- Add `"open"` to `face_vent_patterns` and to `FACE_VENT_PATTERNS`. The default stays
  `triangles`, so `body-face.stl` keeps its meaning.
- In `ventPatternCutter()`, `"open"` is a region covering the whole panel, so the existing
  margin-hexagon clip shapes it (and the front-circle clip, when that is on). The result is a
  3 mm rim (`face_vent_margin`) plus the two bosses. No new clipping code.
- `face_panel_thickness("open")` = `face_thickness`, so the depth is unchanged.
- Back face: `"open"` falls back to `"triangles"` in both `back_face_vent_pattern()` and
  `back_face_vent()`. The back stays a grille.
- Half-cell foot: follows the face as it does today (an open cell matches an open face). This
  is my call.

### Dust ring: `dust_support = "none" | "veins" | "voronoi"`

A new config variable, default `"none"`. That way `body-dust.stl` stays byte-for-byte the
plain ring, and old links keep working.

**Common to both rib modes:**
- The ribs fill the window from the front face (y = 0) to the glue-pocket floor
  (y = depth − 0.32). The fabric then lies flat against the ribs' backs, in the plane it
  already uses at the edges, and is glued to both.
- Their ends are buried in the ring. The ribs are clipped to a plain hexagonal prism a
  chamfer plus 0.2 mm wider than the window, then unioned with the ring, so a rib fills the
  chamfer up to its surface and meets it flush, and never reaches the flat band or the label.
  The label is cut from the finished part, so it cannot be refilled.
  - Clipping to the chamfer cone itself (the first version) rendered clean and was wrong.
    The stepped slabs meet the cone's smooth face within hundredths of a millimetre and
    leave microscopic voids and tunnels: genus 4 and 14 where the openings say 3 and 6.
- **Wing cross-section:** the air comes from the front, so the round nose is at y = 0 and the
  tail faces the fabric. Half-thickness follows a NACA-00xx-style thickness curve over the
  chord (the full ring depth, about 3.6 mm). Parameters: `dust_rib_max` (default 1.6 mm, at
  about 30% of the chord), `dust_rib_tail` (default 0.8 mm, the printable floor, so no
  knife-edge).
- It is built as a stack of thin slabs in y, each the rib plan offset to that slab's
  thickness. It prints face-up, so y is the print's Z, and the slabs are effectively the
  print layers. Slab count: one per 0.2 mm, so about 18.
- **Nested-skeleton rule.** Every slab's plan is one skeleton grown by half that slab's
  width, so consecutive outlines nest strictly. Two outlines that share a stretch of edge
  and then part pinch to an edge four faces meet at, which welds into a non-manifold mesh.
  So nothing of fixed size is unioned into a plan: the vein hub grows with the veins, and
  the voronoi cells are bounded well outside the window, so no cell edge runs along it.
- Overhang: the rib narrows towards the bed, about 9° off vertical at the defaults. That is
  fine without supports.

**veins:**
- Three ribs, 120° apart, each a curved centreline from the window's inner hexagon to a
  small rounded hub at the centre. The hub sits in front of the fan's motor hub, where there
  is no airflow, so the junction costs nothing acoustically.
- The curve is a circular arc bending by `dust_vein_bend` (default 45°). `dust_vein_sweep`
  (+1/−1) chooses its hand: it should curve against the blades' sweep, so a blade's leading
  edge crosses the rib at an angle instead of along it. The builder reads the fan's rotation
  arrow (seen from the intake) and sets the default.
- Three ribs share no factor with a seven-blade fan. David counted 7 blades on the real
  NF-A9 (2026-11-27), so 3 veins stands.

**voronoi:**
- About 6 hand-placed, deterministic seed points in config, `dust_voronoi_seeds`, chosen
  inside the window so that no cell is a sliver.
- Cells are computed in OpenSCAD as half-plane intersections (6 seeds × 5 bisectors), not
  imported from an SVG, so the seeds stay editable. The ribs are the window minus the cells,
  each cell inset by half the slab's thickness. Corners are rounded by the same offset.
- The website preview and the existing `voronoi` face pattern are unrelated. The name is
  shared on purpose (same look), but the axes are separate.

### Pipeline and website

- `generate-stl.sh`: the dust ring leaves the shared-parts loop and gets its own loop over
  `DUST_SUPPORTS=(none veins voronoi)` in `variant-matrix.sh`. `none` keeps `body-dust.stl`,
  and the others are `body-dust-veins.stl` and `body-dust-voronoi.stl`. The label-limit
  harvest keeps reading the default render.
- Manifest: a new `dustSupport` axis, `{values, default}`, resolved on the dust slot only.
  Types in `website/types/manifest.ts`, resolution in `website/lib/resolve.ts`, a selector in
  `configurator.tsx` next to the vent pattern, and URL state like `vent`.
- The fixture manifest and the tests are updated to match.

### Tests

- `test-vent-patterns.sh`: `open` renders as one body, with both bosses present.
- `test-variant-matrix.sh` and `test-manifest.sh`: the new pattern, the back-face fallback
  and the new dust axis.
- New `test-dust-support.sh`, for every `dust_support` value:
  - one body, no non-manifold edges, and OpenSCAD's genus equal to the openings the ribs
    leave (none 1, veins `dust_vein_count`, voronoi one per seed), also at chamfers 0, 1
    and 1.5 and with five veins;
  - the ribs run exactly from the front face to the glue-pocket floor;
  - the label removes the same volume from every ring (the band is untouched);
  - the browser's pruned tree renders each rib ring byte-identically;
  - the asserts refuse an unknown mode, a trailing edge under 0.8 mm and an oversized hub.
- `test-dust-clip-fit.sh` runs every vent pattern crossed with every dust support.
  `test-dust-label.sh` stays calibrated on the plain ring and pins `dust_support="none"`.
- Website: resolve and preview tests for the `dustSupport` axis and the `open` fallback.

### Acceptance

1. All the suites above pass. `./scripts/generate-stl.sh --local` publishes every new part.
2. Print the `open` face and one rib ring (veins first). Listen against the bare fan.
   - Pass: no audible tone above the bare fan.
   - Then compare **none**, **veins** and **voronoi** by ear and record the ranking on the card.
3. The fabric stays flat at full fan speed, and nothing touches the blades.

## Left to the builder

- The exact thickness curve and arc construction, within the parameters above.
- The voronoi seed placement (it has to look organic and leave no sliver cells).
- The hub diameter (keep it inside the fan's motor hub, about 35 mm).
- The default for `dust_vein_sweep`, once the fan's rotation has been read.

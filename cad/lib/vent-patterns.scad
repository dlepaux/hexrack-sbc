// ============================================================================
// VENT PATTERNS - Decorative perforations for flat panels
// ============================================================================
// ventPatternCutter() emits the SOLID that gets differenced out of a panel to
// open it up. Every mode produces the holes, never the webs, so a caller swaps
// modes without touching the panel outline, its bosses, or anything unioned on
// afterwards.
//
// Frame convention: the panel lies in the XZ plane and is extruded along +Y.
// The cutter is written in the same frame the face uses -- the panel itself is
// built as translate([0, 0, (-size + flat_to_flat)/2]) honeycomb_box(size, t),
// but the cutter is NOT wrapped in that translate, so its footprint centre is
// [size/2, ., flat_to_flat/2]. Pass it as a sibling of the panel, undtranslated.
//
// Use: use <lib/vent-patterns.scad>
// ============================================================================

include <../config.scad>
use <shapes.scad>

// ============================================================================
// DISPATCH
// ============================================================================

// Parameters:
//   size      - Panel bounding width/height (X and Z); hexagon point-to-point
//   thickness - Panel thickness along Y
//   mode      - One of face_vent_patterns
//   margin    - Solid rim kept inside the hexagon edge, measured at the flats
module ventPatternCutter(size, thickness, mode = face_vent_pattern, margin = face_vent_margin) {
  assert(contains(face_vent_patterns, mode),
         str("ventPatternCutter: unknown pattern \"", mode,
             "\" -- expected one of ", face_vent_patterns));

  // The rim is not decoration. A gyroid strand runs the full width of the panel,
  // so with nothing tying the two halves back together it saws the face into
  // separate bodies as soon as the front circle stops filling the outer ring.
  // Clipping every mode to the same inset hexagon makes that impossible, and
  // costs the closed-cell modes nothing but edge slivers they were better off
  // without.
  intersection() {
    // Only the gyroid varies through the panel depth, so it is the one mode that
    // builds its own solid instead of being a flat region lifted into place.
    if (mode == "voronoi")
      voronoiCutter(size, thickness);
    else if (mode == "gyroid")
      gyroidCutter(size, thickness);
    else
      ventCutterFrame(size, -EPS, thickness + 2 * EPS)
        ventPattern2D(size, mode);

    translate([0, 0, (-size + hex_flat_to_flat(size)) / 2])
      honeycomb_box_inner(size, thickness, margin, 0, 2 * EPS);
  }
}

// The flat modes as a 2D region centred on the origin, sized to cover a `size`
// square with room to spare for the diagonal of the hexagon.
module ventPattern2D(size, mode) {
  if (mode == "triangles")
    trianglePattern(size, size, face_vent_triangle_cell, face_vent_triangle_wall,
                    face_vent_triangle_radius, face_vent_triangle_stagger);
  else if (mode == "grid")
    gridPattern(size, size, face_vent_grid_slot, face_vent_grid_gap,
                face_vent_grid_segment, face_vent_grid_spine, face_vent_grid_stagger);
}

// Lifts a 2D region into the panel frame, centred on the hexagon and occupying
// the depth window [y0, y0 + depth].
module ventCutterFrame(size, y0, depth) {
  translate([size / 2, y0, hex_flat_to_flat(size) / 2])
    rotate([-90, 0, 0])
      linear_extrude(depth)
        children();
}

// ============================================================================
// VORONOI (imported asset)
// ============================================================================

// The SVG is 2000x2000 drawn at 2x the panel, so only its middle quarter lands
// on the face. Its placement is tuned to the asset rather than derived -- the
// cell layout is not symmetric, and this framing is the one that was chosen.
module voronoiCutter(size, thickness) {
  svg_size = 2000;
  scale_factor = size / svg_size * 2;

  translate([0, 0, -100])
  translate([size / 2, -EPS, 0])
  rotate([-90, 0, 0])
  linear_extrude(thickness + 2 * EPS)
    scale([scale_factor, scale_factor])
      translate([-svg_size / 2, -svg_size / 2])
        import("../assets/voronoi_svg.svg");
}

// ============================================================================
// GYROID (curved tunnels)
// ============================================================================
//
// Imported, not computed. The gyroid is an implicit surface and OpenSCAD cannot mesh
// one, so assets/gyroid-tunnels.stl is meshed offline by
// scripts/generate-gyroid-asset.py and scaled into place here.
//
// The previous implementation solved the level set as y(x) per slice and stacked the
// slices as prisms. That is bounded by real mathematics, not by tuning: the closed form
// exists only while |sin(phase)| <= sqrt(1/2), so the sweep across a panel can never
// exceed 90 degrees -- a quarter turn, at any thickness or period -- and the stack cost
// 1.52M facets and 79s at the default settings. The asset has no phase limit, carries no
// staircase, and renders in seconds.
//
// The solid is one of the gyroid's two interpenetrating labyrinths. Subtracting it
// leaves the other as material, so the holes are continuous curved tunnels and the
// remaining web is a single connected network.

// Parameters:
//   size      - Panel bounding width/height (X and Z); hexagon point-to-point
//   thickness - Panel depth along Y; one full period for a complete turn
//   period    - Physical size of one tunnel cell, in mm
module gyroidCutter(size, thickness,
                    period = face_vent_gyroid_period,
                    depth  = face_vent_gyroid_asset_depth) {
  height = hex_flat_to_flat(size);
  span_y = depth * period;

  // ONE seamless block, not a tiled cell. Tiling makes a far smaller asset and was
  // tried first, but marching cubes caps each cell at its own boundary and those caps do
  // not land exactly on the neighbour's, so the union left the panel in 3-7 pieces at
  // some periods and 1 at others -- erratic rather than converging, which is the
  // signature of a seam artefact rather than of real geometry. A panel in pieces still
  // renders and exports clean, so this is bought deliberately: a larger committed asset
  // in exchange for a result that is stable.
  cells = face_vent_gyroid_asset_cells;
  span_x = cells[0] * period;
  span_z = cells[1] * period;

  assert(span_x >= size && span_z >= height,
         str("face_vent_gyroid_period ", period, " is too small: the asset spans ",
             cells[0], "x", cells[1], " cells (", span_x, "x", span_z,
             "mm) but the panel needs ", size, "x", height,
             "mm. Raise the period, or regenerate the asset with more cells."));

  // A panel deeper than the asset would only be cut part-way, leaving tunnels that never
  // break out of the back face.
  assert(span_y >= thickness,
         str("gyroidCutter: the asset spans ", depth, " periods (", span_y,
             "mm at period ", period, ") but the panel is ", thickness,
             "mm. Regenerate assets/gyroid-tunnels.stl with a larger --depth."));

  // Centred on the panel footprint, and centred through its depth so the asset's end
  // caps fall outside the panel and both faces open.
  translate([(size - span_x) / 2,
             (thickness - span_y) / 2,
             (height - span_z) / 2])
    scale(period)
      import(face_vent_gyroid_asset, convexity = 12);
}

// ============================================================================

// TRIANGLES
// ============================================================================

// An equilateral triangle of the given edge length, apex up, centred on its
// centroid and rounded at the corners. offset(r) grows a triangle's inradius by
// r, i.e. its edge by 2*r*sqrt(3), so the seed is shrunk by that much first and
// the result measures `edge` again.
module roundedTriangle(edge, radius) {
  seed = edge - 2 * radius * sqrt(3);
  assert(seed > 0,
         str("roundedTriangle: radius ", radius, " rounds away an edge of ", edge));

  offset(r = radius, $fn = 24)
    rotate(90)
      circle(d = 2 * seed / sqrt(3), $fn = 3);
}

// Rows of alternating up and down triangles. Row j spans y in [j*h, (j+1)*h]:
// up triangles sit on its floor at x = i*cell, down triangles hang from its
// ceiling half a cell along.
//
// Alternate rows are shifted by `stagger` of a cell. At 0 the rows line up into
// the strict triangular tiling, which stacks every up triangle directly on the
// apex of the one below and reads as vertical columns. At 0.5 each row lands on
// the gaps of the row beneath, so an apex points into the web above it instead
// of at another apex -- the same nesting a brick bond gives, on a lattice that
// otherwise looks striped.
// Parameters:
//   cell    - Lattice edge length
//   wall    - Web left between neighbouring holes
//   radius  - Corner rounding on each hole
//   stagger - Fraction of a cell that alternate rows shift by
module trianglePattern(width, height, cell, wall, radius, stagger) {
  h = cell * sqrt(3) / 2;
  hole = cell - wall * sqrt(3);   // shrinking the inradius by wall/2 costs wall*sqrt(3) of edge
  assert(hole > 0,
         str("trianglePattern: wall ", wall, " closes a cell of ", cell));

  cols = ceil(width / cell / 2) + 1;
  rows = ceil(height / h / 2) + 1;

  // Centred on the panel means mirror-symmetric about its midline, and for a
  // triangular lattice that is a placement question, not a translation you can
  // eyeball. Reflection has to send every up triangle onto a real down triangle:
  //
  //   vertically, an up at j*h + h/3 lands on a down at k*h + 2h/3 only if the
  //   origin sits on a ROW BOUNDARY (hence no y shift here) and k = -j-1;
  //   horizontally, j -> -j-1 also flips the row parity, so the target row is
  //   the staggered one -- and at stagger 0.5 its half-cell offset is exactly
  //   where the mirror image lands.
  //
  // So the row range must be closed under j -> -j-1, which [-rows-1, rows] is,
  // and the column range needs one spare on the low side to receive it. Put the
  // origin on a triangle centroid instead and none of it lines up: that is the
  // half-row drift this replaced.
  translate([-cell / 2, 0])
    for (j = [-rows - 1 : rows]) {
      // j % 2 is -1 on odd negative rows, so test against zero rather than one.
      shift = (j % 2 == 0) ? 0 : stagger * cell;

      for (i = [-cols - 1 : cols]) {
        translate([i * cell + cell / 2 + shift, j * h + h / 3])
          roundedTriangle(hole, radius);

        translate([i * cell + cell + shift, j * h + 2 * h / 3])
          rotate(180)
            roundedTriangle(hole, radius);
      }
    }
}

// ============================================================================
// GRID (cyberpunk)
// ============================================================================

// A slot with semicircular ends.
module stadium(length, thickness) {
  assert(length >= thickness,
         str("stadium: length ", length, " is shorter than its ", thickness, " ends"));

  hull()
    for (sx = [-1, 1])
      translate([sx * (length - thickness) / 2, 0])
        circle(d = thickness, $fn = 24);
}

// Horizontal slots in rows, each row broken into segments by vertical spines.
// The spines line up into continuous columns by default, which is what makes it
// a grid rather than a brick bond, and it is also the stiffer of the two: the
// columns carry load straight across the rows instead of stepping around them.
// Parameters:
//   slot    - Slot height
//   gap     - Web between rows
//   segment - Slot length
//   spine   - Web between slots within a row
//   stagger - Fraction of a column pitch that alternate rows shift by
module gridPattern(width, height, slot, gap, segment, spine, stagger) {
  pitch_x = segment + spine;
  pitch_y = slot + gap;
  cols = ceil(width / pitch_x / 2) + 1;
  rows = ceil(height / pitch_y / 2) + 1;

  for (j = [-rows : rows]) {
    // j % 2 is -1 on odd negative rows, so test against zero rather than one.
    shift = (j % 2 == 0) ? 0 : stagger * pitch_x;

    for (i = [-cols : cols])
      translate([i * pitch_x + shift, j * pitch_y])
        stadium(segment, slot);
  }
}

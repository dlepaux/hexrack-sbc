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
// GYROID (open channels)
// ============================================================================

// One strand of the gyroid level set, y as an explicit function of x, both in
// degrees of the unit lattice:
//
//   sin(x)cos(y) + sin(y)cos(z0) + sin(z0)cos(x) = 0
//
// Collecting the y terms as R sin(y + phi) makes it solvable rather than
// implicit, which is what keeps this a handful of polygons instead of a
// marching-squares field:
//
//   R = sqrt(cos(z0)^2 + sin(x)^2),  phi = atan2(sin(x), cos(z0))
//   sin(y + phi) = -sin(z0)cos(x) / R
//
// The asin then needs |argument| <= 1 at every x, which holds exactly while
// sin(z0)^2 <= 1/2 -- hence the phase assert. `branch` picks between the sine's
// two solutions: they are the two strands crossing one 360 degree cell.
function gyroid_y(x, z0, branch) =
  let (r   = sqrt(pow(cos(z0), 2) + pow(sin(x), 2)),
       phi = atan2(sin(x), cos(z0)),
       a   = asin(-sin(z0) * cos(x) / r))
  branch == 0 ? a - phi : 180 - a - phi;

// A strand thickened into a slot, in lattice degrees.
//
// The half-width is applied VERTICALLY and scaled by sqrt(1 + y'^2), which is
// exactly the vertical distance that sits `half` away from the curve measured
// perpendicular. Keeping every sample on its own vertical line is what
// guarantees a simple polygon: a true normal offset folds over itself wherever
// the curve turns tighter than the slot is wide, and OpenSCAD would render the
// self-intersection as a hole in the slot rather than an error.
module gyroidStrand(z0, branch, half, x0, x1, steps) {
  dx = (x1 - x0) / steps;
  probe = dx / 2;

  edge = [ for (i = [0 : steps])
             let (x = x0 + i * dx,
                  y = gyroid_y(x, z0, branch),
                  slope = (gyroid_y(x + probe, z0, branch)
                           - gyroid_y(x - probe, z0, branch)) / (2 * probe),
                  rise = half * sqrt(1 + slope * slope))
             [x, y, rise] ];

  polygon(concat([ for (p = edge)                 [p[0], p[1] + p[2]] ],
                 [ for (i = [steps : -1 : 0]) let (p = edge[i]) [p[0], p[1] - p[2]] ]));
}

// The gyroid is a 3D structure, so cutting one slice and extruding it straight
// through the panel gives slots with vertical walls -- an extruded picture of a
// gyroid, not a gyroid. Sweeping the slice across the panel depth is what makes
// the walls shear and twist the way a printed one does. The lattice is
// isotropic, so a millimetre of depth is worth the same degrees as a millimetre
// across the face.
//
// Stacked as thin prisms rather than lofted between slices: hull() would be the
// smooth way and is useless here, because it is convex, and the convex hull of a
// wavy strand is a blob that swallows the entire pattern. Each step is a print
// layer or less, so the staircase is below what the slicer can resolve.
//
// Parameters:
//   size      - Panel bounding width/height
//   thickness - Panel depth the pattern is cut through
//   layers    - Slices stacked through that depth
module gyroidCutter(size, thickness,
                    period = face_vent_gyroid_period,
                    slot = face_vent_gyroid_slot,
                    phase = face_vent_gyroid_phase,
                    samples = face_vent_gyroid_samples,
                    layers = face_vent_gyroid_layers) {
  // Degrees of lattice crossed between the front and back faces of the panel.
  sweep = thickness * 360 / period;

  // gyroidPattern() solves the level set in closed form, which only exists while
  // |sin(z)| <= sqrt(1/2). Every slice in the sweep has to satisfy that, not just
  // the middle one, so the usable phase band narrows as the panel gets thicker
  // relative to the cell.
  assert(abs(phase) + sweep / 2 <= 45,
         str("gyroidCutter: a ", thickness, "mm panel sweeps ", sweep,
             " degrees of lattice at period ", period,
             ", which leaves phase no further than ", 45 - sweep / 2, " from zero"));

  step = (thickness + 2 * EPS) / layers;

  for (k = [0 : layers - 1])
    // Each prism carries the phase at its own mid-depth, and overruns its
    // neighbour by EPS so the stack fuses into one solid.
    ventCutterFrame(size, -EPS + k * step, step + EPS)
      gyroidPattern(size, size, period, slot,
                    phase - sweep / 2 + (k + 0.5) * sweep / layers, samples);
}

// One slice of the lattice, as a 2D region.
// Parameters:
//   width, height - Area to cover, in mm
//   period        - mm spanned by one full 360 degree lattice cell
//   slot          - Slot width, measured perpendicular to the strand
//   phase         - Which slice of the gyroid this is, in degrees
//   samples       - Polygon samples per cell along a strand
module gyroidPattern(width, height, period, slot, phase, samples) {
  assert(abs(sin(phase)) <= sqrt(0.5),
         str("gyroidPattern: phase ", phase, " has no closed-form strand -- ",
             "|sin(phase)| must stay at or below sqrt(1/2)"));
  assert(slot < period / 2,
         str("gyroidPattern: slot ", slot, " leaves no web at period ", period));

  deg_per_mm = 360 / period;
  reach_x = (width / 2 + period) * deg_per_mm;   // strands must overrun the panel
  cells_y = ceil((height / 2 + period) * deg_per_mm / 360);
  steps = ceil(2 * reach_x / 360 * samples);

  scale([period / 360, period / 360])
    for (branch = [0, 1], j = [-cells_y : cells_y])
      translate([0, j * 360])
        gyroidStrand(phase, branch, slot / 2 * deg_per_mm, -reach_x, reach_x, steps);
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

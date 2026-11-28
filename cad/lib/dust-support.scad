// ============================================================================
// DUST SUPPORT - Wing-section ribs that hold the filter fabric flat
// ============================================================================
// dustSupportSolid() emits the ribs for one dust_support mode, centred on the origin in
// XZ and running from the front face (y = 0) back to y = chord. It knows nothing about
// the ring: sectionDust() places it and clips it to the window opening, so a rib end
// meets the chamfer and the walls exactly as they are.
//
// 2D plans are drawn as seen from the FRONT of the case (+x right, +y up), so the
// config's angles and seeds read the way the part looks on the desk.
//
// Why ribs, why here, and why a wing section: plan/silent-front-design.md.
//
// Use: use <lib/dust-support.scad>
// ============================================================================

include <../config.scad>

// Rib width is a print constraint, not a taste: below two 0.4mm lines the slicer either
// drops the wall or prints it as one unsupported line that breaks off the bed.
DUST_RIB_PRINT_FLOOR = 0.8;

// ============================================================================
// SECTION
// ============================================================================

// Symmetric NACA 00xx half-thickness at x along the chord (0 = nose, 1 = tail),
// unscaled. Its maximum is at x = 0.3.
function naca00_raw(x) =
  0.2969 * sqrt(x) - 0.1260 * x - 0.3516 * pow(x, 2) + 0.2843 * pow(x, 3) - 0.1015 * pow(x, 4);

// Full rib width at x along the chord. The nose keeps its round NACA shape; behind the
// thickest point the taper stops at dust_rib_tail, so the trailing edge is blunt where a
// true airfoil would be a knife-edge no printer can lay down.
function dust_rib_width(x) =
  let (w = dust_rib_max * naca00_raw(x) / naca00_raw(0.3))
  x < 0.3 ? w : max(dust_rib_tail, w);

// ============================================================================
// DISPATCH
// ============================================================================

// Parameters:
//   mode       - One of dust_supports
//   window_p2p - Point-to-point diameter of the ring's window hexagon
//   chord      - Rib depth along Y, front face to the fabric
module dustSupportSolid(mode, window_p2p, chord) {
  assert(contains(dust_supports, mode),
         str("dustSupportSolid: unknown dust_support \"", mode,
             "\" -- expected one of ", dust_supports));
  assert(dust_rib_tail >= DUST_RIB_PRINT_FLOOR,
         str("dust_rib_tail ", dust_rib_tail, " is under the ", DUST_RIB_PRINT_FLOOR,
             "mm two-line floor; the trailing edge will not print"));
  assert(dust_rib_max >= dust_rib_tail,
         str("dust_rib_max ", dust_rib_max, " is thinner than dust_rib_tail ", dust_rib_tail));
  assert(chord > 0, str("dustSupportSolid: chord ", chord, " leaves no depth for a rib"));

  // A stepped section, one slab per print layer. The part prints front face up, so Y is
  // the print's Z and a slab IS what the slicer lays down -- a smooth loft would buy
  // nothing the printer can reproduce, at many times the facets.
  n  = max(1, ceil(chord / dust_rib_layer));
  dy = chord / n;

  if (mode != "none")
    for (k = [0 : n - 1])
      // Slabs abut exactly; Manifold fuses coplanar contact. What it cannot fuse is two
      // slab OUTLINES that share a stretch of boundary and then part: the step between
      // them pinches to an edge four faces meet at, which welds into a non-manifold mesh.
      // So every plan below is its skeleton grown by w/2 -- one family, strictly nested
      // as w changes -- and no fixed-size shape is unioned into it.
      translate([0, k * dy, 0])
        rotate([-90, 0, 0])
          linear_extrude(dy)
            // rotate([-90,0,0]) sends 2D +y to -Z; mirror it back so plans read as seen
            // from the front.
            mirror([0, 1])
              dustSupportPlan(mode, window_p2p, dust_rib_width((k + 0.5) / n));
}

// One layer of the ribs, at width w: a skeleton grown by w/2.
module dustSupportPlan(mode, window_p2p, w) {
  if (mode == "veins")
    veinsPlan(window_p2p, w);
  else if (mode == "voronoi")
    voronoiPlan(window_p2p, w);
}

// ============================================================================
// VEINS
// ============================================================================

// Points along one vein: a circular arc from the hub at the origin to `reach` along
// `phi`, turning by dust_vein_bend on the way. Closed form for an arc of constant
// curvature, heading t0 -> t0 + s*bend: x = s*r*(sin t - sin t0), y = s*r*(cos t0 - cos t),
// with r chosen so the chord is exactly `reach`.
function vein_points(phi, reach, bend = dust_vein_bend, s = dust_vein_sweep, n = 24) =
  bend == 0
    ? [for (k = [0 : n]) (k / n * reach) * [cos(phi), sin(phi)]]
    : let (r  = (reach / 2) / sin(bend / 2),
           t0 = phi - s * bend / 2)
      [for (k = [0 : n])
         let (t = t0 + s * bend * k / n)
         s * r * [sin(t) - sin(t0), cos(t0) - cos(t)]];

// A polyline drawn with a round pen of width w.
module stroke(points, w) {
  for (k = [0 : len(points) - 2])
    hull() {
      translate(points[k])     circle(d = w, $fn = 16);
      translate(points[k + 1]) circle(d = w, $fn = 16);
    }
}

module veinsPlan(window_p2p, w) {
  assert(dust_vein_count >= 1, str("dust_vein_count ", dust_vein_count, " draws no vein"));
  assert(dust_vein_bend >= 0 && dust_vein_bend < 180,
         str("dust_vein_bend ", dust_vein_bend, " must be in [0, 180)"));
  assert(abs(dust_vein_sweep) == 1,
         str("dust_vein_sweep ", dust_vein_sweep, " must be +1 or -1"));
  // The NF-A9's motor hub is ~35mm; past it the junction stands in the blades' airflow.
  assert(dust_vein_hub > w && dust_vein_hub <= 35,
         str("dust_vein_hub ", dust_vein_hub, " must sit inside the fan's ~35mm motor hub"));

  // Past the window's corners, so every vein runs into the ring wherever it lands; the
  // caller's clip trims it to the opening.
  reach = window_p2p / 2 + 2;

  // Grown with the veins, so the hub is domed by the same section and reaches
  // dust_vein_hub only at the thickest layer.
  circle(d = dust_vein_hub - dust_rib_max + w, $fn = 48);
  for (i = [0 : dust_vein_count - 1])
    stroke(vein_points(dust_vein_angle + i * 360 / dust_vein_count, reach), w);
}

// ============================================================================
// VORONOI
// ============================================================================

// The half-plane of points nearer `a` than `b`: everything behind their bisector.
module halfPlaneNearer(a, b, big = 400) {
  n = b - a;
  translate((a + b) / 2)
    rotate(atan2(n[1], n[0]))
      translate([-big, -big])
        square([big, 2 * big]);
}

module voronoiCell(seeds, i) {
  intersection_for (j = [for (j = [0 : len(seeds) - 1]) if (j != i) j])
    halfPlaneNearer(seeds[i], seeds[j]);
}

// The window less every cell, each cell shrunk by half a rib so neighbours leave one rib
// between them, and re-rounded by dust_voronoi_round so the junctions read as grown
// rather than cut. Shrinking more as w grows is the same nested family the veins use.
module voronoiPlan(window_p2p, w) {
  seeds = dust_voronoi_seeds;
  apothem = window_p2p * cos(30) / 2;
  assert(len(seeds) >= 2, "dust_voronoi_seeds needs at least two seeds to draw a rib");
  for (s = seeds)
    assert(norm(s) < apothem,
           str("voronoi seed ", s, " lies outside the ", 2 * apothem, "mm window"));

  difference() {
    // Past the window and past the cells' own bound; the caller's clip trims it.
    circle(d = window_p2p + 2 * (dust_rib_max + dust_voronoi_round + 2) / cos(30), $fn = 6);
    for (i = [0 : len(seeds) - 1])
      offset(r = dust_voronoi_round)
        offset(delta = -(w / 2 + dust_voronoi_round))
          intersection() {
            // Bounded well OUTSIDE the window, so every cell still crosses the window
            // wall after the shrink: no lip of rib runs round the inside of the window,
            // and no cell edge lies ALONG the wall, where consecutive slabs would share
            // it (see dustSupportSolid). The caller's clip ends the ribs at the wall.
            circle(d = window_p2p + 2 * (dust_rib_max + dust_voronoi_round + 1) / cos(30),
                   $fn = 6);
            voronoiCell(seeds, i);
          }
  }
}

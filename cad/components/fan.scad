include <../config.scad>

module fanVisualization92() {
  depth = 25;

  #rotate([90, 0, -180])
  translate([0, 0, -depth + wall_thickness + 3 + 6])
  color("SaddleBrown", 1)
  import("../assets/noctua-92.stl", center=true);
}

// ============================================================================
// FAN CABLE NOTCHES
// ============================================================================
// Four circular notches cut into the fan section's web, one per fan corner, so
// the fan's cable reaches the case interior whichever of its four rotations it
// is mounted in. config.scad carries the reasoning for the placement and for why
// they open into the bore rather than being closed holes.
//
// Authored in the web's own frame: X/Z span [0, size] with the bore centred at
// (size/2, size/2), and Y runs from 0 at the fan-side face to `thickness` at the
// case-side face -- the one carrying the screw countersinks.
//
// Parameters:
//   size          - Panel footprint (body_width)
//   thickness     - Web thickness, along Y
//   bore          - Diameter of the fan bore the notches open into
//   screw_offset  - Fan screw half-pitch, panel centre to a hole per axis
//   radius        - Radius of the notch disc
//   reach         - How far the notch reaches outward past the bore edge
//   angle         - Degrees past the corner diagonal, tracking the cable exit
//   clearance     - Material kept between the notch and the screw countersink
//   chamfer       - Edge break on both faces (0 disables)
//   fn            - Facet count for the disc
module fanWireSlots(size, thickness, bore, screw_offset, radius, reach, angle,
                    clearance, chamfer, fn = 48) {
  bore_r = bore / 2;
  screw_r = screw_offset * sqrt(2);   // the fan screws sit on the corner diagonals
  csink_r = get_screw_spec(fan_screw, "countersink_diameter") / 2;

  // `reach` pins the outer edge and the radius grows inward from it, so widening
  // the notch opens it up along the bore edge without ever walking towards the
  // screw boss. Whatever crosses inside the bore edge is cutting empty space.
  r_out = bore_r + reach;
  r_c = r_out - radius;               // centre of the disc
  bore_overlap = 2 * radius - reach;  // how far it reaches inward past the bore edge

  assert(screw_offset > 0,
         str("fanWireSlots: no fan screw pattern known for a ", bore,
             "mm fan -- extend fan_screw_offset() in config.scad"));
  assert(radius > 0,
         str("fanWireSlots: fan_wire_slot_radius is ", radius, " -- it must be positive"));
  assert(reach > 0,
         str("fanWireSlots: fan_wire_slot_reach is ", reach,
             " -- the notch has to reach outward past the bore edge to be of any use"));
  assert(clearance >= 0,
         str("fanWireSlots: fan_wire_slot_clearance is ", clearance,
             " -- it is the material kept beside the fan screw boss and cannot be negative"));
  assert(bore_overlap > 0,
         str("fanWireSlots: a radius of ", radius, " leaves the notch ", -bore_overlap,
             "mm short of the bore, closing it into a separate hole -- ",
             "fan_wire_slot_radius must exceed half of fan_wire_slot_reach"));
  assert(2 * chamfer < thickness,
         str("fanWireSlots: a ", chamfer, "mm chamfer on both faces consumes the whole ",
             thickness, "mm web -- reduce fan_wire_slot_chamfer"));

  // The notch does not sit straight inboard of a screw once it is rotated off the
  // diagonal, so the clearance cannot be had by subtracting radii -- measure the
  // real centre-to-centre distance to every screw. This reduces to the radial
  // case at angle 0, and it is what lets the angle be changed without silently
  // walking into a boss.
  disc = r_c * [cos(45 + angle), sin(45 + angle)];
  screw_gap = min([for (sa = [45, 135, 225, 315])
                    norm(screw_r * [cos(sa), sin(sa)] - disc)])
              - radius - chamfer - csink_r;
  assert(screw_gap >= clearance,
         str("fanWireSlots: only ", screw_gap, "mm of material between the notch and the fan ",
             "screw countersink, need ", clearance,
             " -- reduce fan_wire_slot_reach, or rotate further off the diagonal"));

  // The notch is subtracted from the web rather than clipped by it, so an
  // oversized reach would silently cut through the tube wall instead of erroring.
  // size * cos(30) / 2 is the largest circle the hexagon holds -- the same
  // conservative bound circularBand() guards itself with.
  assert(r_out + chamfer <= size * cos(30) / 2,
         str("fanWireSlots: the notch reaches r", r_out + chamfer, ", past the ",
             size * cos(30) / 2, " the hexagon holds -- reduce fan_wire_slot_reach"));

  // Adjacent notches sit 90 degrees apart on the same radius. Once they touch it
  // is one continuous slot, not four cable exits, and no other guard notices.
  neighbour_gap = r_c * sqrt(2) - 2 * (radius + chamfer);
  assert(neighbour_gap > 0,
         str("fanWireSlots: a radius of ", radius, " makes adjacent notches overlap by ",
             -neighbour_gap, "mm -- they stop being four separate cable exits"));

  for (diagonal = [45, 135, 225, 315]) {
    a = diagonal + angle;
    centre = [size / 2, 0, size / 2] + r_c * [cos(a), 0, sin(a)];

    // Through cut
    translate(centre - [0, EPS, 0])
      rotate([-90, 0, 0])
        cylinder(r=radius, h=thickness + 2 * EPS, $fn=fn);

    // 45 degree edge break on both faces: widest at the surface, meeting the
    // through cut one chamfer deep. Both cones are grown by EPS along their own
    // taper so the mouth lands exactly on radius + chamfer at the face.
    if (chamfer > 0) {
      // Fan-side face, y = 0
      translate(centre - [0, EPS, 0])
        rotate([-90, 0, 0])
          cylinder(r1=radius + chamfer + EPS, r2=radius, h=chamfer + EPS, $fn=fn);

      // Case-side face, y = thickness -- the one carrying the screw countersinks
      translate(centre + [0, thickness - chamfer, 0])
        rotate([-90, 0, 0])
          cylinder(r1=radius, r2=radius + chamfer + EPS, h=chamfer + EPS, $fn=fn);
    }
  }
}

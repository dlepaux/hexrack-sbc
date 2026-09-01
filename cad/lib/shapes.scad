include <../config.scad>

// ============================================================================
// REUSABLE SHAPE MODULES
// ============================================================================
// Common geometric primitives for the mini rack project.
// Use this file: use <lib/shapes.scad>
// ============================================================================

// ============================================================================
// ROUNDED BOX PRIMITIVES
// ============================================================================

// Creates a solid rounded box (tube shape) along Y-axis
// Parameters:
//   size     - Width and height of the square profile (X and Z)
//   depth    - Length along Y-axis
//   radius   - Corner radius
//   y_offset - Starting Y position (default 0)
module rounded_box(size, depth, radius, y_offset = 0) {
  hull() {
    translate([radius, y_offset, radius])
      rotate([-90, 0, 0])
        cylinder(r=radius, h=depth, $fn=50);

    translate([size - radius, y_offset, radius])
      rotate([-90, 0, 0])
        cylinder(r=radius, h=depth, $fn=50);

    translate([radius, y_offset, size - radius])
      rotate([-90, 0, 0])
        cylinder(r=radius, h=depth, $fn=50);

    translate([size - radius, y_offset, size - radius])
      rotate([-90, 0, 0])
        cylinder(r=radius, h=depth, $fn=50);
  }
}

// Creates inner cutout for hollow shells (slightly extended for clean CSG)
// Parameters:
//   size     - Outer width and height (X and Z)
//   depth    - Length along Y-axis
//   wall     - Wall thickness
//   radius   - Inner corner radius
//   y_offset - Starting Y position
//   eps      - Epsilon extension
module rounded_box_inner(size, depth, wall, radius, y_offset = 0, eps = 0.01) {
  hull() {
    translate([wall + radius, y_offset - eps, wall + radius])
      rotate([-90, 0, 0])
        cylinder(r=radius, h=depth + eps * 2, $fn=50);

    translate([size - wall - radius, y_offset - eps, wall + radius])
      rotate([-90, 0, 0])
        cylinder(r=radius, h=depth + eps * 2, $fn=50);

    translate([wall + radius, y_offset - eps, size - wall - radius])
      rotate([-90, 0, 0])
        cylinder(r=radius, h=depth + eps * 2, $fn=50);

    translate([size - wall - radius, y_offset - eps, size - wall - radius])
      rotate([-90, 0, 0])
        cylinder(r=radius, h=depth + eps * 2, $fn=50);
  }
}

// Creates a hollow rounded shell (box with inner cutout)
// Parameters:
//   size       - Outer width and height (X and Z)
//   depth      - Length along Y-axis  
//   radius     - Outer corner radius
//   wall       - Wall thickness
//   inner_r    - Inner corner radius
//   y_offset   - Starting Y position (default 0)
//   eps        - Epsilon for CSG operations (default 0.01)
module rounded_shell(size, depth, radius, wall, inner_r, y_offset = 0, eps = 0.01) {
  difference() {
    // Outer shell
    rounded_box(size, depth, radius, y_offset);

    // Inner cutout
    rounded_box_inner(size, depth, wall, inner_r, y_offset, eps);
  }
}

// Get the point-to-point width (corner to opposite corner)
function hex_point_to_point(size) = size;

// Get the flat-to-flat width (side to opposite side)
function hex_flat_to_flat(size) = size * cos(30);  // or size * sqrt(3)/2

// ============================================================================
// HONEYCOMB BOX PRIMITIVES (hexagonal prism shapes)
// ============================================================================

// Creates a solid hexagonal prism (tube shape) along Y-axis
// Parameters:
//   size     - Bounding box width and height (X and Z), hexagon is centered within
//   depth    - Length along Y-axis
//   y_offset - Starting Y position (default 0)
module honeycomb_box(size, depth, y_offset = 0) {
  translate([size / 2, y_offset, size / 2])
    rotate([-90, 0, 0])
      cylinder(d=size, h=depth, $fn=6);
}

// Creates inner hexagonal cutout for hollow shells (slightly extended for clean CSG)
// Wall thickness is measured at the flats (thinnest point) to ensure
// the specified wall thickness is the minimum structural thickness.
// Parameters:
//   size     - Outer bounding box width and height (X and Z)
//   depth    - Length along Y-axis
//   wall     - Wall thickness (measured at flats)
//   y_offset - Starting Y position
//   eps      - Epsilon extension
module honeycomb_box_inner(size, depth, wall, y_offset = 0, eps = 0.01) {
  // Compensate for hex geometry: d parameter is point-to-point,
  // but wall thickness is measured flat-to-flat (thinnest point).
  // flat_wall = (size - inner_d) / 2 * cos(30°) → inner_d = size - 2 * wall / cos(30°)
  inner_size = size - 2 * wall / cos(30);
  translate([size / 2, y_offset - eps, size / 2])
    rotate([-90, 0, 0])
      cylinder(d=inner_size, h=depth + eps * 2, $fn=6);
}


module honeycomb_box_inner_twice(size, depth, wall, y_offset = 0, eps = 0.01) {
  // Compensate for hex geometry: d parameter is point-to-point,
  // but wall thickness is measured flat-to-flat (thinnest point).
  // flat_wall = (size - inner_d) / 2 * cos(30°) → inner_d = size - 2 * wall / cos(30°)
  inner_size = size - 4 * wall / cos(30);
  translate([size / 2, y_offset - eps, size / 2])
    rotate([-90, 0, 0])
      cylinder(d=inner_size, h=depth + eps * 2, $fn=6);
}

// Creates a hollow hexagonal shell (honeycomb box with inner cutout)
// Parameters:
//   size     - Outer bounding box width and height (X and Z)
//   depth    - Length along Y-axis
//   wall     - Wall thickness
//   y_offset - Starting Y position (default 0)
//   eps      - Epsilon for CSG operations (default 0.01)
module honeycomb_shell(size, depth, wall, y_offset = 0, eps = 0.01) {
  difference() {
    // Outer shell
    honeycomb_box(size, depth, y_offset);

    // Inner cutout
    honeycomb_box_inner(size, depth, wall, y_offset, eps);
  }
}

// ============================================================================
// SECTION SNAP LIP
// ============================================================================

// Tongue-and-groove ring joining two stacked body sections. Deliberately two
// modules rather than one with a type argument: the halves share only the lip
// depth and the Z centring, and a female call that lost its section_depth would
// place the cutter exactly on top of the male tongue and eat it -- silently, in a
// part that still renders and exports clean.
//
// Both self-centre on the body hexagon, so call them without a translate, and
// both emit a single node so a caller may wrap them in its own intersection().

// The tongue. union() this onto a section: it protrudes lip_depth past the near
// face (negative Y) to enter the neighbouring section's groove, and overlaps the
// section by eps so the union is a real intersection rather than two bodies
// meeting on a coincident plane.
// Parameters:
//   size - Outer hexagon width (default body_width)
//   eps  - CSG overlap into the host section (default EPS)
// A hexagonal frustum along +Y, centred the same way honeycomb_box centres its
// prism. Every lip surface is one of these, so the profiles below read as a list
// of cones rather than a pile of transforms.
// A diameter step of 2 * k / cos(30) over an axial length k is a 45-degree face
// measured at the flats, which is what "chamfer" means for these hexagons.
module _lipCone(size, y, h, d1, d2) {
  translate([size / 2, y, size / 2])
    rotate([-90, 0, 0])
      cylinder(d1 = d1, d2 = d2, h = h, $fn = 6);
}

// How far the tongue can follow the ramp before its tip is too thin to print. The
// ramp brings the section's face out at lip_female_wall / lip_floor_ramp per mm and
// the tongue must retreat at the same rate to clear it, so the two converge and the
// tongue always stops short. Derived rather than set by hand: there is exactly one
// right answer and it moves whenever the ramp or the walls do.
function lipMaleOverlap() =
  lip_floor_ramp <= 0 ? 0
  : max(0, (lip_wall - lip_taper - lip_tip_min) * lip_floor_ramp / lip_female_wall);

// Total length of the tongue: it fills the rebate and then reaches down the ramp.
function lipMaleLength() = lip_depth + lip_floor_gap + lipMaleOverlap();

// What is left uncovered at every seam. Always positive while there is a ramp --
// shrinking lip_floor_ramp is the only thing that closes it.
function lipSeamGap() = lip_floor_ramp - lipMaleOverlap();

// How much deeper than nominal the tongue may sit before its tip touches the ramp.
// The two run parallel, separated by lip_clearance plus whatever lip_taper adds, and
// that separation closes at the ramp's own rate -- so a short ramp buys a small seam
// gap by spending assembly tolerance. The other half of the ramp trade-off.
function lipSeatMargin() =
  lip_floor_ramp <= 0 ? lip_floor_gap
  : (lip_clearance + lip_taper) * lip_floor_ramp / lip_female_wall;

module honeycombLipMale(size = body_width, eps = EPS) {
  length = lipMaleLength();

  // Two slopes, and the knee is where the tongue crosses the rebate floor.
  //   root -> knee : the gentle lip_taper, so it enters loose and closes to
  //                  lip_clearance only when the root reaches the mouth.
  //   knee -> tip  : parallel to the ramp it now slides along, at whatever angle
  //                  that is. Taking 45 degrees for granted only works while
  //                  lip_floor_ramp happens to equal lip_female_wall; any other
  //                  ramp and a 45-degree tip drives straight into it.
  overlap   = lipMaleOverlap();
  ramp_rate = lip_floor_ramp > 0 ? lip_female_wall / lip_floor_ramp : 0;
  knee_wall = lip_wall - lip_taper;
  tip_wall  = knee_wall - overlap * ramp_rate;

  // Following that 45 degrees, the tongue runs out of wall. What is left at the
  // tip has to be something a nozzle can actually lay down.
  assert(tip_wall >= lip_tip_min - 0.001,
         str("honeycombLipMale: a ", lip_floor_ramp, "mm ramp leaves a ", tip_wall,
             "mm tip -- lower lip_taper or lip_tip_min to free up wall"));

  root_d = size - 2 * lip_wall / cos(30);
  knee_d = size - 2 * knee_wall / cos(30);
  tip_d  = size - 2 * tip_wall / cos(30);

  a_slope = overlap > 0 ? (knee_d - tip_d) / overlap : 0;   // steep, 45 deg
  b_slope = (root_d - knee_d) / (length - overlap);             // gentle

  // _lipCone extrudes along +Y, so local y = 0 is the free tip.
  if (debug_lips) #tongue(); else tongue();

  module tongue()
  translate([0, -length + eps, (-size + hex_flat_to_flat(size)) / 2])
  difference() {
    // Full-width tongue, unbroken from root to tip. This outer face is the case's
    // skin across the seam and it is what hides the joint, so it is never
    // chamfered: any break here would expose that much more of the cut.
    _lipCone(size, -eps, length + 2 * eps, size, size);

    // Gentle taper, referenced to the knee so it still reaches lip_wall exactly at
    // the root, and extrapolated past both ends.
    _lipCone(size, -2 * eps, length + 4 * eps,
             knee_d - b_slope * (overlap + 2 * eps),
             root_d + b_slope * 2 * eps);

    // The 45-degree tip. Overruns the knee by eps so its end cap finishes strictly
    // inside the taper above rather than landing tangent to it, which would put
    // two surfaces in the same place again.
    if (overlap > 0)
      _lipCone(size, -2 * eps, overlap + 3 * eps,
               tip_d - a_slope * 2 * eps, knee_d + a_slope * eps);
  }
}

// The groove. difference() this out of a section: it opens the channel in the far
// face, lip_depth back from section_depth. The cutter is grown by eps and shifted
// back half of it in X and Z so its outer surface clears the section's own outer
// surface -- CSG hygiene, not extra clearance. The fit comes from lip_female_wall
// alone.
// Parameters:
//   section_depth - Depth of the host section along Y. REQUIRED: no default, so
//                   a forgotten argument is an undef translate OpenSCAD warns
//                   about rather than a groove silently cut over the tongue.
//   size          - Outer hexagon width (default body_width)
//   eps           - CSG clearance past the outer surface (default EPS)
// How far back from a section's far face honeycombLipFemale() removes material:
// the rebate, its floor gap, and the ramp that fades the cut out. Anything sitting
// on the outer surface -- the intercase dovetail rails especially -- has to stop
// short of this, or it is left standing on a face that was cut away.
function lipFemaleReach() = lip_depth + lip_floor_gap + lip_floor_ramp;

module honeycombLipFemale(section_depth, size = body_width, eps = EPS) {
  depth   = lip_depth + lip_floor_gap;
  outer_d = size + eps;
  face_d  = outer_d - 2 * lip_female_wall / cos(30);   // the rebate face
  slope   = lip_floor_ramp > 0 ? (outer_d - face_d) / lip_floor_ramp : 0;

  // A section shallower than the whole cut would have its own tongue eaten from
  // the root. back_face_thickness is 3mm, so this is not hypothetical -- that
  // section simply has no female, and this keeps it that way.
  reach = lipFemaleReach();
  assert(section_depth > reach,
         str("honeycombLipFemale: section_depth ", section_depth,
             " must exceed the rebate reach ", reach));

  if (debug_lips) #rebate(); else rebate();

  // Local y = 0 is the rebate floor; the mouth is at y = depth.
  //
  // One cutter, one bore. Built as two cutters -- a shell plus a separate ramp
  // wedge -- this had three sets of coincident faces to flicker on: the two
  // cutters shared an outer wall at outer_d exactly, the wedge feathered to a
  // zero-area knife edge where its cone met its own prism, and the cone
  // overshot the rebate face by slope * eps across their overlap. Keeping the
  // bore as one unioned solid inside one difference leaves none of them.
  module rebate()
  translate([-eps / 2,
             section_depth - depth + eps / 2,
             (-size + hex_flat_to_flat(size)) / 2 - eps / 2])
  difference() {
    // Deliberately 2 * eps wider than outer_d: that offset is what keeps this
    // wall clear of the section's own surface and gives the ramp a finite
    // thickness where it starts instead of a knife edge. It cuts only air.
    _lipCone(outer_d, -lip_floor_ramp, lip_floor_ramp + depth + eps,
             outer_d + 2 * eps, outer_d + 2 * eps);

    union() {
      // The rebate face, constant for the full depth of the rebate.
      _lipCone(outer_d, -eps, depth + 2 * eps, face_d, face_d);

      // Below the floor the bore opens back out to the full outer diameter, so
      // the cut ends on a slope rather than a step. The tongue tip stops at
      // y = lip_floor_gap, so none of this touches the fit.
      if (lip_floor_ramp > 0)
        _lipCone(outer_d, -lip_floor_ramp - eps, lip_floor_ramp + eps,
                 outer_d + slope * eps, face_d);
    }
  }
}

// ============================================================================
// ROUNDED PANEL (Internal dividers with rounded corners)
// ============================================================================

// Creates a panel with rounded corners, optionally with center hole
// Parameters:
//   size       - Panel width and height (X and Z)
//   thickness  - Panel thickness (Y)
//   radius     - Corner radius
//   y_pos      - Y position of panel
//   center_hole - Diameter of center hole (0 for no hole)
module roundedPanel(size, thickness, radius, y_pos, center_hole = 0) {
  difference() {
    hull() {
      translate([radius, y_pos, radius])
        rotate([-90, 0, 0])
          cylinder(r=radius, h=thickness, $fn=50);

      translate([size - radius, y_pos, radius])
        rotate([-90, 0, 0])
          cylinder(r=radius, h=thickness, $fn=50);

      translate([radius, y_pos, size - radius])
        rotate([-90, 0, 0])
          cylinder(r=radius, h=thickness, $fn=50);

      translate([size - radius, y_pos, size - radius])
        rotate([-90, 0, 0])
          cylinder(r=radius, h=thickness, $fn=50);
    }

    // Center hole if specified
    if (center_hole > 0) {
      translate([size / 2, y_pos - 0.1, size / 2])
        rotate([-90, 0, 0])
          cylinder(d=center_hole, h=thickness + 10, $fn=100);
    }
  }
}

// ============================================================================
// CIRCULAR BAND (decorative ring traced across a panel)
// ============================================================================

// Creates a solid annular band along the Y-axis, centred in a `size`-wide square
// footprint so it lines up with honeycomb_box()/roundedPanel() built at the same size.
// Unioned onto a perforated panel it fills whatever pattern it crosses, drawing a
// clean circle without removing ventilation area.
// Parameters:
//   size      - Bounding footprint width and height (X and Z); band centres on size/2
//   thickness - Band depth along Y
//   diameter  - Centreline Ø of the band
//   band      - Radial width (band straddles `diameter`, half either side)
//   y_offset  - Starting Y position (default 0)
//   fn        - Facet count for both walls (default 160)
module circularBand(size, thickness, diameter, band, y_offset = 0, fn = 160) {
  // The band is unioned onto its panel rather than clipped by it, so an oversized
  // diameter would silently spill past the hexagon instead of erroring. size * cos(30)
  // is the hexagon's flat-to-flat, i.e. the largest circle that fits inside it.
  assert(diameter + band <= size * cos(30),
         str("circularBand: Ø", diameter + band, " does not fit the ", size * cos(30),
             " flat-to-flat footprint"));

  difference() {
    translate([size / 2, y_offset, size / 2])
      rotate([-90, 0, 0])
        cylinder(d=diameter + band, h=thickness, $fn=fn);

    translate([size / 2, y_offset - EPS, size / 2])
      rotate([-90, 0, 0])
        cylinder(d=diameter - band, h=thickness + 2 * EPS, $fn=fn);
  }
}

// ============================================================================
// CORNER CYLINDER (for corner brackets with shell overlap)
// ============================================================================

// Creates a full cylinder for corner brackets (ensures deep overlap into shell)
// Parameters:
//   corner_radius - Corner radius from body configuration
//   depth         - Length along Y-axis
//   quadrant      - Kept for API compatibility but not used
module cylinder_brackets(corner_radius, depth, quadrant = "pp") {
  rotate([-90, 0, 0])
    cylinder(r=corner_radius, h=depth, $fn=40);
}

module silicon_pad_receptacle(pad_height = 1, pad_width = 6, pad_length = 14, extra_size = 3) {
  receptacle_width = pad_width + extra_size; // 9mm
  receptacle_length = pad_length + extra_size; // 17mm
  cylinder_radius = receptacle_width / 2; // 4.5mm

  // Two cylinders creating the "o==o" shape
  union() {
    // Left cylinder
    translate([-receptacle_length / 2 + cylinder_radius, 0, pad_height / 2])
      cylinder(r=cylinder_radius, h=pad_height, center=true, $fn=32);

    // Right cylinder
    translate([receptacle_length / 2 - cylinder_radius, 0, pad_height / 2])
      cylinder(r=cylinder_radius, h=pad_height, center=true, $fn=32);

    // Connecting bar in the middle
    translate([0, 0, pad_height / 2])
      cube([receptacle_length - 2 * cylinder_radius, receptacle_width, pad_height], center=true);
  }
}

module pad_holder() {
  // Create recessed receptacle
  difference() {
    // Outer shape
    silicon_pad_receptacle(pad_height=2, pad_width=6, pad_length=pad_length, extra_size=3);

    // Inner recess (smaller pad)
    translate([0, 0, -1]) // Offset by 1mm from bottom
      silicon_pad_receptacle(pad_height=2, pad_width=6, pad_length=pad_length, extra_size=0);
  }

  translate([0, 0, 2]) // Offset by 1mm from bottom
    silicon_pad_receptacle(pad_height=1, pad_width=6, pad_length=pad_length, extra_size=5);

  // Pad
  %translate([0, 0, -1]) // Offset by 1mm from bottom
    color("black", 0.5)
      silicon_pad_receptacle(pad_height=2, pad_width=6, pad_length=pad_length, extra_size=0);
}

module beveledSimpleShell(cutout = false) {
  clearance = OVERLAP * 4;
  male_y_clearance = OVERLAP * 4;
  global_offet = wall_thickness;
  global_sub = global_offet / 2;
  size = body_size - global_offet;
  height_offset = corner_radius * 2;

  translate([global_sub, 0, global_sub]) {
    translate([0, cutout ? 0 : male_y_clearance, 0]) {
      chamfer_size = wall_thickness;
      height = size - height_offset + (cutout ? clearance : -clearance);
      value1 = cutout ? height_offset / 2 - clearance / 2 : height_offset / 2 + clearance / 2;
      adapted_bottom = cutout ? EPS : EPS * 2;
      adapted_top = cutout ? size - EPS : size - EPS * 2;
      adapted_left = cutout ? -EPS : 0;
      adapted_right = cutout ? size + EPS : size;
      inversed_chamfer = -chamfer_size;

      difference() {
        hull() {
          // Chamfer - BOTTOM edge
          translate([value1, 0, adapted_bottom + value1 / 2])
            rotate([0, 90, 0])
              linear_extrude(height=height)
                polygon([[0, 0], [chamfer_size, 0], [0, inversed_chamfer]]);

          // Chamfer - TOP edge
          translate([value1, 0, adapted_top - value1 / 2])
            rotate([0, 90, 0])
              linear_extrude(height=height)
                polygon([[0, 0], [0, inversed_chamfer], [-chamfer_size, 0]]);

          // Chamfer - LEFT edge
          translate([adapted_left + value1 / 2, 0, value1])
            rotate([0, 0, 0])
              linear_extrude(height=height)
                polygon([[0, 0], [-chamfer_size, 0], [0, inversed_chamfer]]);

          // Chamfer - RIGHT edge
          translate([adapted_right - value1 / 2, 0, value1])
            rotate([0, 0, 0])
              linear_extrude(height=height)
                polygon([[0, 0], [0, inversed_chamfer], [chamfer_size, 0]]);
        }

        if (!cutout) {
          signaler_width = 4;
          translate([size / 2 - signaler_width / 2, -wall_thickness - EPS, -EPS])
            cube([signaler_width, wall_thickness + EPS, size / 2]);
        }
      }
    }
  }
}

module back_mounting_bracket() {
  translate([-back_mounting_brackets_width / 2, 0, 0])
    difference() {
      union() {
        // Main cube
        translate([0, 0, 0])
          cube([back_mounting_brackets_width, back_mounting_brackets_depth, back_mounting_brackets_height]);

        // Bevel on right side (top edge)
        translate([back_mounting_brackets_width - back_mounting_brackets_bevel_size, 0, 0])
          rotate([0, 45, 0])
            cube([back_mounting_brackets_bevel_size * sqrt(2), back_mounting_brackets_depth, back_mounting_brackets_bevel_size * sqrt(2)]);

        // Bevel on left side (top edge)
        translate([-back_mounting_brackets_bevel_size, 0, 0])
          rotate([0, 45, 0])
            cube([back_mounting_brackets_bevel_size * sqrt(2), back_mounting_brackets_depth, back_mounting_brackets_bevel_size * sqrt(2)]);
      }

      // Bevel on back edge (top)
      translate([-back_mounting_brackets_back_width / 2 + back_mounting_brackets_width / 2, back_mounting_brackets_depth, 0])
        rotate([45, 0, 0])
          cube([back_mounting_brackets_back_width, back_mounting_brackets_bevel_size * sqrt(2), back_mounting_brackets_bevel_size * sqrt(2)]);

      translate([-back_mounting_brackets_back_width / 2 + back_mounting_brackets_width / 2, -OVERLAP, -back_mounting_brackets_height])
        cube([back_mounting_brackets_back_width, back_mounting_brackets_depth + OVERLAP * 2, back_mounting_brackets_height]);
    }
}

module antiStressCutoutPattern() {
  center_x = body_size / 2;
  center_z = body_size / 2;

  thickness=anti_stress_thickness;
  
  positions = [
    // X, Z, Rotation
    [0, corner_radius*2, 90, -thickness/2, 0], // Bottom Left
    [corner_radius*2, 0, 0, 0, -thickness/2], // Bottom Left
    [0, center_z, 90, -thickness/2, 0], // Left center
    [0, body_size - corner_radius*2, 90, -thickness/2, 0], // Top left
    [corner_radius*2, body_size, 180, 0, thickness/2], // Top left
    [center_x, body_size, 180, thickness/2, 0], // Top center
    [body_size - corner_radius*2, body_size, 180, thickness/2, thickness/2], // Top right
    [body_size, body_size - corner_radius*2, 270, thickness/2, 0], // Top right
    [body_size, center_z, 270, thickness/2, 0], // Right center
    [body_size - corner_radius*2, 0, 0, 0, -thickness/2], // Bottom right
    [body_size, corner_radius*2, 270, thickness/2, 0], // Bottom right
    [center_x, 0, 0, -thickness/2, 0] // Bottom center
  ];
  
  for (pos = positions) {
    translate([pos[0] + pos[3], 0, pos[1] + pos[4]])
      rotate([90, pos[2], 0])
        children();
  }
}

module half_cylinder(type, height = 2) {
  diameter= type == "male" ? 3.9 : 4;
  translate([body_width/2, 0, 0])
  difference() {
    cylinder(r=diameter, h=height + (type == "female" ? EPS : 0), $fn=20);
    cube_width=12;
    translate([-cube_width/2, -cube_width, -EPS])
    cube([cube_width, cube_width, cube_width]);
  }
}
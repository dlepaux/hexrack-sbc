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
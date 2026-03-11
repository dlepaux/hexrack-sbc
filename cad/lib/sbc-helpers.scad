// ============================================================================
// SBC HELPERS - Single Board Computer Mounting
// ============================================================================
// Functions and modules for mounting SBCs (Raspberry Pi, Rock, etc.)
// Uses SBC_Model_Framework for board data.
// Use: use <lib/sbc-helpers.scad>
// ============================================================================

include <../config.scad>
include <../SBC_Model_Framework/sbc_models.cfg>
include <screws.scad>
use <pironman-base.scad>

// ============================================================================
// FUNCTIONS (require sbc_data from SBC_Model_Framework)
// ============================================================================

// Get mounting hole positions from sbc_data
// Only returns main mounting holes (data[0] = "both"), not heatsink or M.2 holes
// For Pironman, returns both Pi5 holes + adapter holes with Z offsets
// Returns: Array of [x, y] or [x, y, z] positions
function get_sbcMountingHoles(model) =
  model == "rpi5_pironman" ? pironman_all_mounting_holes()
  : let (
    s = search([model], sbc_data),
    sindex = 2
  ) [
      for (i = [sindex:11:len(sbc_data[s[0]]) - 1]) if (sbc_data[s[0]][i] == "pcbhole" && sbc_data[s[0]][i + 9][0] == "both") [sbc_data[s[0]][i + 3], sbc_data[s[0]][i + 4]],
  ];

// Get all mounting holes for Pironman (Pi5 + adapter holes)
// Uses positions from pironman-base.scad as source of truth
// Returns: Array of [x, y, z] where z is relative offset (0 for Pi5, 3mm for adapter)
function pironman_all_mounting_holes() =
  let (
    // Get Pi5 holes from framework (add z=0)
    s = search(["rpi5"], sbc_data),
    sindex = 2,
    pi5_holes = [
      for (i = [sindex:11:len(sbc_data[s[0]]) - 1]) if (sbc_data[s[0]][i] == "pcbhole" && sbc_data[s[0]][i + 9][0] == "both") [sbc_data[s[0]][i + 3], sbc_data[s[0]][i + 4], 0], // Add z=0 for Pi5 holes
    ],
    adapter_holes = get_pironman_adapter_holes() // From pironman-base.scad (has z offset)
  ) concat(pi5_holes, adapter_holes);

// Get mounting hole diameter from sbc_data
// Parameters:
//   model - Board model name
//   index - Which hole (0-based), default 0
// Returns: Hole diameter in mm (default 3.5 if not found)
function sbc_hole_diameter(model, index = 0) =
  let (
    // Use rpi5 for pironman since they share the same hole sizes
    lookup_model = model == "rpi5_pironman" ? "rpi5" : model,
    s = search([lookup_model], sbc_data),
    sindex = 2,
    holes = [
      for (i = [sindex:11:len(sbc_data[s[0]]) - 1]) if (sbc_data[s[0]][i] == "pcbhole" && sbc_data[s[0]][i + 9][0] == "both") sbc_data[s[0]][i + 8][0],
    ]
  ) index < len(holes) ? holes[index] : 3.5;

// ============================================================================
// MODULES
// ============================================================================

// Create mounting hole cutouts for SBC
// Cuts through the bottom panel (XY plane) in Z direction
// Uses M2.5-4 pilot holes for SBC mounting screws
// Parameters:
//   model     - Board model name
module sbcMountingHoles(model) {
  holes = get_sbcMountingHoles(model);
  pilot_d = get_screw_spec("M2.5-4", "pilot_hole_diameter");

  for (i = [0:len(holes) - 1]) {
    hole = holes[i];

    translate([hole[0], hole[1], -EPS])
      cylinder(d=pilot_d, h=panel_thickness + 2 * EPS, $fn=60);
  }
}

// Create support pillars under SBC mounting holes
// Hexagonal stepped pillars with M2.5-4 pilot holes for screws
// Parameters:
//   model       - Board model name
//   board_z     - Board Z offset from panel top
module sbcMountingSupports(
  model,
  board_z,
  rot,
  body_height,
  type="top"
) {
  holes = get_sbcMountingHoles(model);
  pilot_d = get_screw_spec("M2.5-4", "pilot_hole_diameter");
  outer_d_top = pilot_d + support_pillar_inset;
  separationZlevel = drawer_board == "rock5b+" ? 35 : 22;

  difference() {

    union() {
      for (i = [0:len(holes) - 1]) {
        hole = holes[i];

        // Check if hole has Z offset (3D position)
        hole_z_offset = len(hole) > 2 ? hole[2] : 0;
        pillar_h = board_z + hole_z_offset - wall_thickness + OVERLAP;

        translate([hole[0], hole[1], 0]) {
          color("orange")
          difference() {
            // Outer hexagonal stepped shape
            _sbc_hexagonal_stepped_pillar(outer_d_top, pillar_h, rot);

            // M2.5-4 pilot hole for screw threading
            translate([0, 0, pillar_h - 10 - EPS])
              cylinder(d=pilot_d, h=10 + 2 * EPS, $fn=60);
          }
        }
      }
    }

    if (type == "bottom") {
      translate([-body_width, -back_depth, separationZlevel])
      cube([body_width*2, back_depth*2, body_height]);
    }

    if (type == "top") {
      translate([-body_width, -back_depth, -body_height + separationZlevel])
      cube([body_width*2, back_depth*2, body_height]);
    }

    for (i = [0:len(holes) - 1]) {
      hole = holes[i];

      // Check if hole has Z offset (3D position)
      hole_z_offset = len(hole) > 2 ? hole[2] : 0;
      pillar_h = board_z + hole_z_offset - wall_thickness + OVERLAP;

      // We should add a pin to the top part
      pin_width=3.4;
      pin_height=7;
      norm_offset=norm([pin_width, pin_width, 0]);
      if (type == "bottom") {
        translate([hole[0], hole[1] - norm_offset/2, separationZlevel - pin_height + EPS])
        rotate([0, 0, 45])
        cube([pin_width, pin_width, pin_height]);
      }
    }
  }

  for (i = [0:len(holes) - 1]) {
    hole = holes[i];

    // Check if hole has Z offset (3D position)
    hole_z_offset = len(hole) > 2 ? hole[2] : 0;
    pillar_h = board_z + hole_z_offset - wall_thickness + OVERLAP;

    // We should add a pin to the top part
    pin_width=3.25;
    pin_height=6;
    norm_offset=norm([pin_width, pin_width, 0]);
    if (type == "top") {
      translate([hole[0], hole[1] - norm_offset/2, separationZlevel - pin_height + EPS])
      rotate([0, 0, 45])
      cube([pin_width, pin_width, pin_height]);
    }
  }
}

// Internal: Create hexagonal stepped pillar
// Each step is 5mm tall, with 20% radius increase per step (going down)
// Includes a thin base ring at the bottom for stability
// Parameters:
//   top_diameter - Diameter at the top
//   height       - Total height of pillar
module _sbc_hexagonal_stepped_pillar(top_diameter, height, rot) {
  step_height = 5; // mm per step
  radius_increase = 0.135; // 20% per step
  base_ring_height = 1.5; // mm - thin base for stability
  base_ring_extra_radius = 0.15; // 15% extra radius for base ring

  // Calculate number of steps
  num_steps = ceil(height / step_height);
  remainder = height - (num_steps - 1) * step_height;

  // Calculate bottom step radius for base ring reference
  steps_from_top_bottom = num_steps - 1;
  bottom_radius_multiplier = pow(1 + radius_increase, steps_from_top_bottom);
  bottom_radius = (top_diameter / 2) * bottom_radius_multiplier;
  base_ring_radius = bottom_radius * (1 + base_ring_extra_radius);

  // Build from top to bottom (reverse order)
  for (step = [num_steps - 1:-1:0]) {
    // Calculate radius for this step (smaller at top, larger at bottom)
    steps_from_top = num_steps - step - 1;
    radius_multiplier = pow(1 + radius_increase, steps_from_top);
    current_radius = (top_diameter / 2) * radius_multiplier;

    // Top hexagon gets full step_height, bottom gets remainder
    current_step_height = (step == 0) ? remainder : step_height;

    // Calculate Z position (working from top down)
    z_position = (step == 0) ? 0 : (height - (num_steps - step) * step_height);

    // Create hexagonal prism (flat-top orientation)
    translate([0, 0, z_position])
      linear_extrude(height=current_step_height)
        rotate(rot)
          circle(r=current_radius, $fn=6);
  }

  // Add stabilization base ring at the bottom
  translate([0, 0, -EPS])
    linear_extrude(height=base_ring_height)
      rotate(rot)
        circle(r=base_ring_radius, $fn=6);
}

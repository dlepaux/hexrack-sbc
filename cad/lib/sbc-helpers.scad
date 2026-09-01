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
include <theaded-inserts.scad>
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


// Z of the top of the support under a hole -- where its insert boss ends and its
// insert pocket begins. Public because back-bottom.scad cuts those pockets into
// the shell floor from outside this file, and a second copy of this formula
// would silently drift until the pockets missed the bosses.
function sbcSupportTopZ(h, board_z, wt, standoff) =
  board_z + (len(h) > 2 ? h[2] : 0) - wt - standoff + OVERLAP;

// Rotate a hole [x, y, (z)] about Z. Used to express holes in the *world*
// frame so canoes always run along Y no matter how the board is rotated.
function _canoe_rotz(h, a) =
  [ h[0]*cos(a) - h[1]*sin(a),
    h[0]*sin(a) + h[1]*cos(a),
    len(h) > 2 ? h[2] : 0 ];

// Unique X columns, within tolerance (first occurrence wins)
function _canoe_columns(holes) =
  [ for (i = [0:len(holes)-1])
      if (len([ for (j = [0:i-1])
                  if (abs(holes[j][0] - holes[i][0]) < canoe_group_tol) 1 ]) == 0)
        holes[i][0] ];

// 2D lens footprint: two arcs, symmetric, centred on origin. `width` is the X
// extent — across the canoe, matching the insert boss diameter. The arcs are
// offset along Y so the points land at bow and stern, along the canoe's run.
module _canoe_lens(width, bulge = canoe_bulge) {
  hw  = width / 2;
  r   = hw / bulge;
  off = sqrt(max(r*r - hw*hw, 0));
  intersection() {
    translate([0,  off]) circle(r = r, $fn = 64);
    translate([0, -off]) circle(r = r, $fn = 64);
  }
}

// One cross-section of the canoe: the lens footprint at Y, extruded to height h
module _canoe_prism(y, h, w) {
  translate([0, y, 0])
    linear_extrude(h)
      _canoe_lens(w);
}

// Top-view footprint of a canoe running from y_a to y_b (2D, for the skirt)
module _canoe_footprint(y_a, y_b, w) {
  hull() {
    translate([0, y_a]) _canoe_lens(w);
    translate([0, y_b]) _canoe_lens(w);
  }
}

// Tallest pillar required by the holes sitting at Y within a column
function _canoe_h_at(members, y, board_z, standoff) =
  max([ for (h = members) if (h[1] == y)
          sbcSupportTopZ(h, board_z, wall_thickness, standoff) ]);

// Create support pillars under SBC mounting holes
// Hexagonal stepped pillars with M2.5-4 pilot holes for screws
// Parameters:
//   model       - Board model name
//   board_z     - Board Z offset from panel top
// Height of the canoe top at a given hole
module sbcMountingSupports(
  model,
  board_z,
  rot = [0, 0, 0],
  body_height,
  support_mandatory_standoff_height,
) {
  // Callers wrap this module in rotate(rot). Express the holes in the rotated
  // (world) frame and undo that rotation on the geometry, so the canoes always
  // run along the world Y axis while the bosses stay on their holes.
  spin    = rot[2];
  holes   = [ for (h = get_sbcMountingHoles(model)) _canoe_rotz(h, spin) ];
  boss_d  = get_insert_min_boss("M2.5");
  canoe_w = boss_d + 2 * canoe_wall;
  cols    = _canoe_columns(holes);

  rotate([0, 0, -spin])
  difference() {
    union() {
      for (x = cols) {
        members = [ for (h = holes) if (abs(h[0] - x) < canoe_group_tol) h ];
        ys      = [ for (h = members) h[1] ];
        y_lo    = min(ys);
        y_hi    = max(ys);

        h_lo = _canoe_h_at(members, y_lo, board_z, support_mandatory_standoff_height);
        h_hi = _canoe_h_at(members, y_hi, board_z, support_mandatory_standoff_height);

        // Run past the outermost holes so the canoe reaches the shell walls and
        // prints as one continuous rail. The caller intersects the supports with
        // the part envelope, which is what actually sets the ends.
        y_end_lo = y_lo - canoe_overrun;
        y_end_hi = y_hi + canoe_overrun;

        color("orange")
        translate([x, 0, 0]) {

          // --- canoe body ---------------------------------------------------
          // Flat out to each end, then one ramp per consecutive pair of holes.
          // A single hull across the whole run would linearly interpolate
          // between the end heights, lifting the canoe top above a lower hole
          // and capping its insert pocket. Segmenting keeps every boss at its
          // own height, however far the ends are extended.
          hull() {
            _canoe_prism(y_end_lo, h_lo, canoe_w);
            _canoe_prism(y_lo,     h_lo, canoe_w);
          }
          hull() {
            _canoe_prism(y_hi,     h_hi, canoe_w);
            _canoe_prism(y_end_hi, h_hi, canoe_w);
          }
          for (y = ys) {
            above = [ for (b = ys) if (b > y) b ];
            if (len(above) > 0) {
              y_next = min(above);
              hull() {
                _canoe_prism(y,      _canoe_h_at(members, y,      board_z, support_mandatory_standoff_height), canoe_w);
                _canoe_prism(y_next, _canoe_h_at(members, y_next, board_z, support_mandatory_standoff_height), canoe_w);
              }
            }
          }

          // --- base fillet skirt --------------------------------------------
          // Same footprint, offset outward, tapering to zero over the
          // fillet radius. Gives a concave-ish flare without minkowski cost.
          if (canoe_base_fillet > 0) {
            fsteps = 6;
            for (i = [0 : fsteps - 1]) {
              z0 = canoe_base_fillet * i / fsteps;
              z1 = canoe_base_fillet * (i + 1) / fsteps;
              // outward offset shrinks as we rise
              o0 = canoe_base_fillet * (1 - sin(90 * i / fsteps));
              translate([0, 0, z0])
                linear_extrude(z1 - z0 + EPS)
                  offset(r = o0)
                    _canoe_footprint(y_end_lo, y_end_hi, canoe_w);
            }
          }

          // --- insert bosses at each hole -----------------------------------
          for (h = members) {
            ph = sbcSupportTopZ(h, board_z, wall_thickness, support_mandatory_standoff_height);
            translate([0, h[1], ph - EPS])
            insert_boss("M2.5");
          }
        }
      }
    }

    // --- insert pockets, carved after everything is unioned -----------------
    for (h = holes) {
      ph = sbcSupportTopZ(h, board_z, wall_thickness, support_mandatory_standoff_height);
      translate([h[0], h[1], ph])
      insert_hole_mask("M2.5");
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

include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/fan.scad>
use <../../components/drawers.scad>
use <../../components/mounting-holes.scad>

use <../../SBC_Model_Framework/sbc_models.scad>
include <../../SBC_Model_Framework/sbc_models.cfg>

use <../../lib/sbc-helpers.scad>
use <../../lib/pironman-base.scad>

// ============================================================================
// COOLER DUCT
// ============================================================================
// Carries the 92mm bore's air into the pocket the cooler's own 60mm fan came out of.
//
// Built as outer-hull MINUS inner-hull rather than as a swept shell: the profiles are a
// clipped circle at one end and a rounded square at the other, and a sweep tears at the
// corners where one becomes the other.
//
// `shrink` insets BOTH profiles, which is what makes the second hull a genuine inner
// surface rather than a scaled copy. `ext` lengthens it past both faces -- WITHOUT that
// the inner hull ends flush with the outer and leaves a thin skin capping each end. The
// duct then renders and exports as a clean, sealed, completely useless tube; the old
// scale([1,1.0001,1]) was meant to do this job and moved the end by 0.0015mm.

// Inlet: the fan bore with a segment taken off its BOTTOM. The remaining arc meets the
// bore edge, which fuses the duct to the web and is what makes it fit the circle; the
// segment is the bleed opening feeding the under-board plenum and the fan cable.
//
// Local +Y maps to world -Z through the rotate([-90,0,0]) below, so the world-bottom is
// clipped by keeping local y BELOW a threshold. Getting that backwards puts the opening
// on the roof, pointing at nothing.
module _ductInletProfile(shrink = 0) {
  r = fan_size_mode / 2 - shrink;
  intersection() {
    circle(r = r, $fn = 120);
    translate([-r - 1, -r - 1])
      square([2 * r + 2, (r - duct_bleed_height) + (r + 1) + shrink]);
  }
}

module _ductOutletProfile(shrink = 0) {
  side = duct_outlet_size - 2 * duct_fit_clearance - 2 * shrink;
  offset(r = duct_outlet_radius - shrink)
    square([side - 2 * duct_outlet_radius, side - 2 * duct_outlet_radius], center = true);
}

module _ductShell(shrink = 0, ext = 0) {
  bore_z = hex_flat_to_flat(body_width) / 2;

  // Converging transition, bore to nozzle, climbing from the bore centre to the fan
  // frame centre.
  hull() {
    translate([body_width / 2, fan_depth - ext, bore_z])
      rotate([-90, 0, 0]) linear_extrude(EPS) _ductInletProfile(shrink);
    translate([body_width / 2, fan_depth + duct_transition_length, duct_outlet_z])
      rotate([-90, 0, 0]) linear_extrude(EPS) _ductOutletProfile(shrink);
  }

  // Straight nozzle, running through the fan's pocket.
  translate([body_width / 2, fan_depth + duct_transition_length, duct_outlet_z])
    rotate([-90, 0, 0])
      linear_extrude(duct_nozzle_length + ext)
        _ductOutletProfile(shrink);
}

// A local widening of the bleed opening at the bottom of the skirt, so the 92mm fan's
// 4-pin connector can be threaded out of the airway and down to the board. Sized for the
// plug, not the wires: a hole that only fits the cable means cutting the plug off.
module _ductCableChannel() {
  bore_z = hex_flat_to_flat(body_width) / 2;
  translate([body_width / 2 - duct_cable_width / 2,
             fan_depth - OVERLAP,
             bore_z - fan_size_mode / 2 + duct_bleed_height - EPS])
    cube([duct_cable_width, duct_transition_length + 2 * OVERLAP, duct_cable_height]);
}

module fanDuct() {
  // The bleed opening is what feeds the under-board plenum, and it closes the moment it
  // is asked for nothing. Assert rather than clamp: silently opening it would change the
  // airflow split behind the user's back.
  assert(duct_bleed_height > 0 && duct_bleed_height < fan_size_mode / 2,
         str("duct_bleed_height (", duct_bleed_height, ") must be between 0 and the bore ",
             "radius (", fan_size_mode / 2, "), or the bleed that feeds the under-board ",
             "plenum is either sealed or the whole lower half of the bore"));

  difference() {
    _ductShell(0, 0);
    _ductShell(duct_wall, OVERLAP);
    _ductCableChannel();
  }
}

module sectionFan() {
  body_height = hex_flat_to_flat(body_width);

  difference() {
    union() {
      translate([0, 0, (-body_width + body_height)/2])
      honeycomb_shell(body_width, fan_depth, 2.6);

      // Male
      honeycombLipMale();

      translate([0, fan_depth - 3, 0])
      intersection() {
        translate([0, 0, (-body_width + body_height)/2])
        honeycomb_box(body_width, 3, 0);

        translate([0, 0, (-body_width + body_height)/2])
        roundedPanel(
          body_width,
          wall_thickness,
          corner_radius,
          0,
          center_hole=fan_size_mode
        );
      }
    }

    // Female
    honeycombLipFemale(fan_depth);

    translate([0, -OVERLAP*5, 0])
    frontfaceMountingHolesFront(type="through", body_height=body_height);

    #translate([0, 0, (-body_width + body_height)/2])
    rotate([0, 0, 180])
    translate([-body_width, -fan_depth, 0])
    fanMountingHoles();

    // Cable exits for the fan, one per corner so any of its four rotations works.
    // Cut only into the 3mm web above -- at this radius the section is hollow, so
    // nothing else is in the way. See config.scad for the placement reasoning.
    if (enable_fan_wire_slots)
      translate([0, fan_depth - 3, (-body_width + body_height)/2])
      fanWireSlots(
        size = body_width,
        thickness = 3,
        bore = fan_size_mode,
        screw_offset = fan_screw_offset(fan_size_mode),
        radius = fan_wire_slot_radius,
        reach = fan_wire_slot_reach,
        angle = fan_wire_slot_angle,
        clearance = fan_wire_slot_clearance,
        chamfer = fan_wire_slot_chamfer
      );
  }

  // Duct onto the cooler. Unioned after the difference() above so the section's own
  // cutters -- the female lip, the mounting holes, the fan screws -- cannot reach into
  // it. It sits inside the bore they are all outside of.
  if (duct_enabled())
    fanDuct();

  if (show_fan) {
    %translate([body_width/2, fan_depth, body_height/2])
    fanVisualization92();
  }
}

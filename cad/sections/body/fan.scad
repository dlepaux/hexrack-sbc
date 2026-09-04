include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/fan.scad>
use <../../components/drawers.scad>
use <../../components/mounting-holes.scad>

use <../../SBC_Model_Framework/sbc_models.scad>
include <../../SBC_Model_Framework/sbc_models.cfg>

use <../../lib/sbc-helpers.scad>
use <../../lib/pironman-base.scad>

// The transition from the 92mm bore to the cooler's intake. Two hulls: the outer
// surface, and the same shape inset by duct_wall subtracted from it. The profiles are
// a circle and a rounded square, so a swept shell would tear at the corners where one
// becomes the other -- hull-minus-hull cannot.
//
// `shrink` shrinks BOTH profiles, which is what makes the second hull a true inner
// surface rather than a scaled copy of the outer one.
module _ductShell(shrink = 0) {
  bore_z = hex_flat_to_flat(body_width) / 2;

  hull() {
    translate([body_width / 2, fan_depth, bore_z])
      rotate([-90, 0, 0])
        cylinder(d = duct_inlet_diameter - 2 * shrink, h = EPS, $fn = 96);

    translate([body_width / 2, fan_depth + duct_length, duct_outlet_z])
      rotate([-90, 0, 0])
        linear_extrude(EPS)
          offset(r = duct_outlet_radius - shrink)
            square([duct_outlet_size - 2 * duct_outlet_radius,
                    duct_outlet_size - 2 * duct_outlet_radius], center = true);
  }
}

// Vanes across the bleed ring, from the duct's rim out to the bore edge. Overlapped a
// millimetre into both so the union is a real intersection rather than two solids
// touching on a coincident plane.
module _ductVanes() {
  bore_z = hex_flat_to_flat(body_width) / 2;
  r_in   = duct_inlet_diameter / 2 - 1;
  r_out  = fan_size_mode / 2 + 1;

  for (i = [0 : duct_vane_count - 1])
    translate([body_width / 2, fan_depth - 3, bore_z])
      rotate([0, i * 360 / duct_vane_count, 0])
        translate([r_in, 0, -duct_vane_thickness / 2])
          cube([r_out - r_in, 3 + duct_length / 2, duct_vane_thickness]);
}

module fanDuct() {
  // The bleed ring is the duct's whole reason for being undersized, and it closes the
  // moment the inlet reaches the bore. That is not hypothetical: fan_size_mode=80 with
  // the stock 80mm inlet seals it exactly, fuses the duct skirt into the web, and still
  // exports one clean body -- the under-board plenum simply gets no air, and nothing
  // says so. Assert rather than clamp: silently shrinking the inlet would change the
  // airflow split behind the user's back.
  assert(duct_inlet_diameter < fan_size_mode,
         str("duct_inlet_diameter (", duct_inlet_diameter, ") must be smaller than the ",
             "fan bore (", fan_size_mode, ") or the bleed ring that feeds the ",
             "under-board plenum is sealed"));

  difference() {
    union() {
      _ductShell(0);
      _ductVanes();
    }
    // Bore through. Over-length at both ends so the duct is open, not capped: EPS alone
    // leaves a skin the slicer happily prints and which blocks the whole airway.
    translate([0, -OVERLAP, 0]) scale([1, 1.0001, 1]) _ductShell(duct_wall);
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

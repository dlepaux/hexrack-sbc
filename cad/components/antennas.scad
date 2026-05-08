include <../config.scad>

// ============================================================================
// WIFI ANTENNA — MOUNT MASK + VISUALIZATION
// ============================================================================
// Local frame for both modules:
//   Z-axis aligned. Origin at OUTSIDE face center of the panel hole.
//   +Z points OUT of case (antenna body sits here).
//   -Z points INTO case (threaded post + nut sit here).
// Caller rotates and translates to place on the back panel.
// ============================================================================

// Hole + nut trap. Subtract from the back panel.
//   Through hole: full panel thickness, Ø = thread_d + clearance
//   Nut trap recess: hex pocket on the INSIDE face, depth = nut_thick + clearance/2
module antenna_hole_mask(
  thread_d = antenna_thread_diameter,
  clearance = antenna_clearance,
  nut_af = antenna_nut_flats,
  nut_thick = antenna_nut_thickness,
  panel_thick = back_face_thickness,
) {
  through_d = thread_d + clearance;
  trap_af = nut_af + clearance;
  trap_d = trap_af / cos(30);          // hex vertex-to-vertex (OpenSCAD draws by this)
  trap_depth = nut_thick + clearance / 2;

  // Through hole — extended well past the panel on both sides so the cut
  // remains clean even when the caller shifts the mask Y to align the nut
  // trap with the connector hex shoulder.
  overshoot = panel_thick * 2;
  translate([0, 0, -panel_thick - overshoot])
    cylinder(h = panel_thick + 2 * overshoot, d = through_d, $fn = 40);

  // Nut trap — extends inward beyond the panel inside face so it always
  // cuts the trap recess regardless of small placement offsets.
  translate([0, 0, -panel_thick - overshoot])
    cylinder(h = trap_depth + overshoot, d = trap_d, $fn = 6);
}

// Visualization of the female bulkhead mount only.
// Hex shoulder seats in the nut trap on the inside face; threaded male
// post extends OUTWARD through the panel so the antenna can mate on the
// outside of the case.
module antenna_visualization(
  thread_d = antenna_thread_diameter,
  thread_len = antenna_thread_length,
  nut_af = antenna_nut_flats,
  nut_thick = antenna_nut_thickness,
  panel_thick = back_face_thickness,
) {
  nut_hex_d = nut_af / cos(30);

  // Hex shoulder — integral to the connector body, captured by the nut trap.
  // Spans z = -panel_thick to z = -panel_thick + nut_thick (flush inside face).
  color("DimGray", 0.9)
    translate([0, 0, -panel_thick])
      cylinder(h = nut_thick, d = nut_hex_d, $fn = 6);

  // Threaded post — extends from top of shoulder OUTWARD through panel
  // and protrudes outside the case (where the antenna screws on).
  color("Silver", 0.9)
    translate([0, 0, -panel_thick + nut_thick])
      cylinder(h = thread_len, d = thread_d, $fn = 24);
}

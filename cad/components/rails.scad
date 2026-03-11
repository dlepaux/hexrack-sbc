include <../config.scad>

module rail() {
  cube([
    rail_width,
    (
      body_depth - front_part_depth - // Back depth
      (panel_thickness + corner_bracket_width + drawer_clearance)
    ),
    rail_height
  ]);
}

// Triangular support bracket under rails for added strength
module railSupport(side="right") {
  support_height = rail_height * 2;  // Height of the triangular support
  support_width = rail_width;        // How far the support extends from wall (X axis)
  rail_length = body_depth - front_part_depth - (panel_thickness + corner_bracket_width + drawer_clearance);
  
  // Triangle profile on X-Z plane, extruded along Y (rail length)
  if (side == "right") {
    // Right side: slope goes from wall (right) down toward center (left)
    translate([0, 0, -support_height])
    rotate([90, 0, 0])
    linear_extrude(height=rail_length)
    polygon(points=[
      [0, 0],                          // Bottom left (toward center)
      [0, support_height],             // Top left (under rail)
      [-support_width, support_height] // Top right (at wall)
    ]);
  } else {
    // Left side: slope goes from wall (left) down toward center (right)
    translate([0, 0, -support_height])
    rotate([90, 0, 0])
    linear_extrude(height=rail_length)
    polygon(points=[
      [0, 0],                          // Bottom right (toward center)
      [0, support_height],             // Top right (under rail)
      [support_width, support_height]  // Top left (at wall)
    ]);
  }
}

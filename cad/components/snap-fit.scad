include <../config.scad>

module drawerSnapFitFemale(side="right") {
  // Create mounting holes at each position
  for (z_pos = rail_positions) {
    if (side == "right") {
      snapFitFemale("right", z_pos);
    }

    if (side == "left") {
      snapFitFemale("left", z_pos);
    }
  }
}

// Snap fit female cutout - hole for male snap to catch into
module snapFitFemale(side, z_position) {
  // Add clearance to female cutout for easier fit
  clearance = 0.2;
  snap_x_position = side == "right" ? body_size - wall_thickness - snap_height - EPS : wall_thickness;
  
  // Center the cutout in the rail
  translate([snap_x_position, body_depth - front_part_depth - snap_y_position, rail_height + z_position])
  rotate([0, 90, 0])
  cylinder(d=snap_diameter, h=snap_height + EPS, $fn=30);
}

module snapFitMale(side = "right", pw, ph) {
    snap_x_position = side == "right" ? pw - snap_height : 0;
    
    translate([snap_x_position, snap_y_position, 0])
    rotate([0, 90, 0])
    cylinder(d=snap_diameter, h=snap_height, $fn=30);
}
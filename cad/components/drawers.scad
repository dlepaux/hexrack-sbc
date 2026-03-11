include <../config.scad>
use <rails.scad>

module drawerRails(side="right") {
  // Create rails at each position
  for (i = [0:len(rail_positions)-1]) {
    z_pos = rail_positions[i];

    // Ignoring the first rail
    if (i!=0) {
      rail_y_position = 0;

      if (side == "right") {
        // Right rail (flush against right inner wall)
        translate([body_size - wall_thickness - rail_width + OVERLAP, rail_y_position, z_pos])
        rail();
        
        // Support bracket under right rail
        // translate([body_size - wall_thickness + OVERLAP, body_depth - front_part_depth - (panel_thickness + corner_bracket_width + drawer_clearance), z_pos + OVERLAP])
        // railSupport("right");
      }

      if (side == "left") {
        // Left rail (flush against left inner wall)
        translate([wall_thickness - OVERLAP, rail_y_position, z_pos])
        rail();
        
        // Support bracket under left rail
        // translate([wall_thickness - OVERLAP, body_depth - front_part_depth - (panel_thickness + corner_bracket_width + drawer_clearance), z_pos + OVERLAP])
        // railSupport("left");
      }
    }
  }
}

/**
 * Helper function to sum drawer heights up to index i
 */
function sumHeights(i, total=0) = 
  i <= 0 ? total :
  sumHeights(
    i - 1,
    total + drawer_config[i-1][0][1]  // Get height from preset
  );


module drawersVisualization() {
  translate([0, 0, 0]) { // Volontary offset to test fitting
    // Render all configured drawers from bottom to top
    for (i = [0:len(drawer_config)-1]) {
      // Get drawer preset and visibility
      preset = drawer_config[i][0];
      visible = drawer_config[i][1];

      // Extract preset values
      board = preset[0];
      
      // Calculate Z position (accumulate heights from bottom)
      z_position = wall_thickness + wall_thickness + sumHeights(i);

      // Only render if visible
      if (visible) {
        // Render drawer at calculated position
        // Drawers insert from back: front panel at Y=0 (body front)
        translate([
          wall_thickness + wall_thickness + drawer_clearance,  // Align with left inner wall + clearance
          body_depth - front_part_depth,
          z_position
        ])
        color([0.5, 0.7, 1.0, 0.4])  // Light blue, semi-transparent
        // Rotate 180 degrees to face back of body
        translate([drawer_width - wall_thickness, 0, 0])
        rotate([0, 0, 180])
        drawer(
          preset = preset,
          part = "both",
          number = i
        );
      }
    }
  }
}

include <../config.scad>
use <nuts.scad>
use <../lib/shapes.scad>

/**
 * Module: Front Face Mounting Holes
 * Description: Renders the mounting holes for the front face panel.
 */
// Helper module: positions for all 4 frontface mounting holes
module frontfaceMountingPattern(body_height) {
  center_x = body_width/2;
  center_z = body_height/2;
  screw_offset=9.25;

  positions = [
    [center_x, body_height - screw_offset], // Top-center
    [center_x, screw_offset]
  ];
  
  for (pos = positions) {
    translate([pos[0], 0, pos[1]])
      rotate([90, 0, 0])
        children();
  }
}

module frontfaceMountingHolesBack() {
  // Pilot holes on the front section for screwing the frontface
  frontfaceMountingPattern()
  screw_hole_mask("M4-50", "through");

  nut_height=30;
  nut_thickness=3;
  translate([0, -wall_thickness - nut_thickness, 0])
  translate([0, fan_depth + nut_height - wall_thickness, 0])
  frontfaceMountingPattern()
  m4_nut_trap(height=nut_height);
}

module frontfaceMountingHolesFront(offset_y=0, type="front", body_height) {
  // Through holes + countersink on frontface/dust filter horizontal bands
  y_pos = face_depth - wall_thickness - EPS + offset_y;
  
  translate([0, y_pos, 0])
  frontfaceMountingPattern(body_height)
  screw_hole_mask("M4-50", type);

  if (type == "back") {
    nut_height = 30;
    // Add M4 nut traps on back section
    min_engagement_depth = get_screw_spec("M4-50", "min_engagement_depth");
    translate([0, y_pos + nut_height + 4, 0])
    frontfaceMountingPattern(body_height)
    m4_nut_trap(height=nut_height);
  }
}

/**
 * Module: Fan Mounting Holes
 * Description: Renders the mounting holes for the Noctua fan.
 */
// Helper module: fan mounting hole patterns (170mm and 154mm)
module fanMountingPattern() {
  center_x = body_width / 2;
  center_z = body_width / 2;
  

  offset_fan = fan_screw_offset(fan_size_mode);
  
  positions = [
    [center_x - offset_fan, center_z - offset_fan],
    [center_x + offset_fan, center_z - offset_fan],
    [center_x - offset_fan, center_z + offset_fan],
    [center_x + offset_fan, center_z + offset_fan],
  ];
  
  for (pos = positions) {
    translate([pos[0], 0, pos[1]])
      rotate([90, 0, 0])
        children();
  }
}

module fanMountingHoles() {
  fanMountingPattern()
  rotate([0, 0, 0])
  screw_hole_mask(fan_screw, "front");
}

/**
 * Module: Body Screw Holes
 * Description: Renders the assembly screw holes for joining front and back sections.
 */
// Helper module: positions for 4 assembly screw holes (top and bottom only)
module assembly_screw_pattern(body_height) {
  screw_spacing = 9.25;
  
  // 1 screw per corner: along Z axis (top and bottom mounting brackets only)
  positions = [
    // Left
    [screw_spacing, body_height/2],                        // Along Z (vertical)
    // Right
    [body_width - screw_spacing, body_height/2] // Along Z (vertical)
  ];
  
  for (pos = positions) {
    translate([pos[0], 0, pos[1]])
      rotate([90, 0, 0])
        children();
  }
}

module assemblyScrewHoles(body_height, type="front") {
  // 4 assembly screw holes at 190x190mm pattern for joining front and back sections
  depth = wall_thickness + EPS*2 + 10;
  y_pos = -EPS;
  
  translate([0, y_pos, 0])
  assembly_screw_pattern(body_height)
  screw_hole_mask("M3-30", type);

  if (type == "back") {
    nut_height = 30;
    // Add M4 nut traps on back section
    min_engagement_depth = get_screw_spec("M3-30", "min_engagement_depth");
    translate([0, y_pos + nut_height + 4, 0])
    assembly_screw_pattern(body_height)
    m4_nut_trap(height=nut_height);
  }
}

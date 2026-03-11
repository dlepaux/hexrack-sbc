include <../config.scad>

function getRotation(side) =
  side == "front" ?  [0, 0, 0] :
  side == "bottom" ?  [90, 0, 180] :
  side == "left" ?  [90, -90, 180] :
  side == "right" ?  [90, 90, 180] :
  [0, 0, 0];

module dovetailRail(side = "bottom", length, tolerance=0, angle=75, base_width=dovetail_rail_base_width, height=dovetail_rail_height) {
  // Calculate horizontal offset based on angle and height
  offset = height / tan(angle);

  rotate(getRotation(side))
  linear_extrude(height=length)
  polygon([
    [tolerance, 0],  // top left - moved inward
    [offset + tolerance, -height],  // bottom left - moved inward
    [base_width - offset - tolerance, -height],  // bottom right - moved inward
    [base_width - tolerance, 0]  // top right - moved inward
  ]);
}

module dovetailRailMaleBottom(preset, pw, rail_length = drawer_depth - dovetail_stop_distance - drawer_clearance) {
  // Alignment rails for bracket positioning
  rail_x_center = dovetail_rail_base_width/2;
  rail_x_start = corner_bracket_width/2 + dovetail_rail_base_width/2;
  rail_y_start = panel_thickness - OVERLAP;
  rail_z_start = panel_bottom_thickness + dovetail_rail_penetration + OVERLAP * 2 - dovetail_clearance/2;

  show_middle_support = preset_show_middle_support(preset);
  show_dual_middle_support = preset_show_dual_middle_support(preset);
  space_between_dual_middle_support = preset_space_between_dual_middle_support(preset);

  // Middle support rail
  if (show_middle_support) {
    translate([pw/2 + rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("bottom", rail_length, dovetail_clearance);
  } 

  // Dual middle support rail
  if (show_dual_middle_support) {
    translate([pw/2 + space_between_dual_middle_support/2 + rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("bottom", rail_length, dovetail_clearance);

    translate([pw/2 - space_between_dual_middle_support/2 + rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("bottom", rail_length, dovetail_clearance);
  }

  if (show_sides_support) {
    // Left rail (under tall bracket)
    translate([rail_x_start, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("bottom", rail_length, dovetail_clearance);
    // Right rail (under tall bracket)
    translate([pw - corner_bracket_width/2 + rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("bottom", rail_length, dovetail_clearance);
  }
}

module dovetailRailMaleFront(preset, pw, ph) {
  rail_length = ph - panel_bottom_thickness * 2;
  rail_x_center = dovetail_rail_base_width/2;
  rail_y_start = panel_thickness + dovetail_rail_penetration + OVERLAP * 2 - dovetail_clearance/2;
  rail_z_start = panel_bottom_thickness * 2;

  show_middle_support = preset_show_middle_support(preset);
  show_dual_middle_support = preset_show_dual_middle_support(preset);
  space_between_dual_middle_support = preset_space_between_dual_middle_support(preset);

  // Middle support rail
  if (show_middle_support) {
    translate([pw/2 - rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("front", rail_length, dovetail_clearance);
  }

  // Dual middle support rail
  if (show_dual_middle_support) {
    translate([pw/2 - space_between_dual_middle_support/2 - rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("front", rail_length, dovetail_clearance);

    translate([pw/2 + space_between_dual_middle_support/2 - rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("front", rail_length, dovetail_clearance);
  }

  if (show_sides_support) {
    // Left rail
    translate([corner_bracket_width/2 - rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("front", rail_length, dovetail_clearance);

    // Right rail
    translate([pw - corner_bracket_width/2 - rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("front", rail_length, dovetail_clearance);
  }
}

module dovetailRailFemale(base_x, pw, ph) {
  // Bottom rail
  rail_bottom_length = drawer_depth - dovetail_stop_distance;
  rail_bottom_x_start = base_x + dovetail_rail_base_width/2;
  rail_bottom_y_start = panel_thickness - EPS;
  rail_bottom_z_start = panel_bottom_thickness + dovetail_rail_penetration + OVERLAP * 2;

  // Front rail
  rail_front_length = ph;
  rail_front_x_start = base_x - dovetail_rail_base_width/2;
  rail_front_y_start = panel_thickness + dovetail_rail_penetration + OVERLAP * 2;
  rail_front_z_start = panel_bottom_thickness + dovetail_rail_height;

  difference() {
    union() {
      // Bottom rail cutout
      translate([rail_bottom_x_start, rail_bottom_y_start, rail_bottom_z_start])
      dovetailRail("bottom", rail_bottom_length);

      // Front rail cutout
      translate([rail_front_x_start, rail_front_y_start, rail_front_z_start])
      dovetailRail("front", rail_front_length);
    }
  }
}

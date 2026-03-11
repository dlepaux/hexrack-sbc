include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/fan.scad>
use <../../components/drawers.scad>
use <../../components/mounting-holes.scad>
use <../../components/dovetails.scad>

use <../../SBC_Model_Framework/sbc_models.scad>
include <../../SBC_Model_Framework/sbc_models.cfg>

use <../../lib/sbc-helpers.scad>
use <../../lib/pironman-base.scad>
use <feet.scad>


module chocolateBarsPattern() {
  bar_width = 10;
  bar_length = 10;
  bar_height = 1;
  gap = 1;

  step = bar_width + gap;
  num_x = floor(body_width / step) + 1;
  total_width = (num_x - 1) * step + bar_width;
  x_offset = (body_width - total_width) / 2;

  for (x = [0 : step : body_width]) {
    for (y = [0 : bar_length + gap : back_depth]) {
      translate([x + x_offset, y, 0])
      cube([bar_width, bar_length, bar_height]);
    }
  }
}

module sectionBackBottomBase() {
  body_height = hex_flat_to_flat(body_width);

  difference() {
    translate([0, 0, (-body_width + body_height)/2])
    honeycomb_shell(body_width, back_depth, wall_thickness);

    difference() {
      translate([-OVERLAP/2, -OVERLAP/2, body_height/2])
      cube([body_width + OVERLAP, back_depth + OVERLAP, body_height/2 + OVERLAP]);
    }

    // Mask to plug the modules together
    diamond_side_width = 30;
    translate([body_width/2, back_depth/2 - norm([diamond_side_width, diamond_side_width, 2])/2, -1])
    rotate([0, 0, 45])
    cube([diamond_side_width, diamond_side_width, 2]);

    // Left side diamond cutout for horizontal stacking
    translate([body_width/8, back_depth/2, body_height/4])
    rotate([0, -120, 0])
    rotate([0, 0, 45])
    cube([diamond_side_width, diamond_side_width, 2], center=true);

    // Right side diamond cutout for horizontal stacking
    translate([7*body_width/8, back_depth/2, body_height/4])
    rotate([0, 120, 0])
    rotate([0, 0, 45])
    cube([diamond_side_width, diamond_side_width, 2], center=true);
  }

  // Left rail
  translate([dovetail_rail_base_width/2 + dovetail_offset_x, 0, body_height/2 - EPS + dovetail_rail_penetration + OVERLAP * 2 - dovetail_clearance/2])
  dovetailRail("bottom", back_depth - 10, dovetail_clearance);

  // Right rail
  translate([body_width + dovetail_rail_base_width/2 - dovetail_offset_x, 0, body_height/2 - EPS + dovetail_rail_penetration + OVERLAP * 2 - dovetail_clearance/2])
  dovetailRail("bottom", back_depth - 10, dovetail_clearance);
}

module sectionBackBottom() {
  body_height = hex_flat_to_flat(body_width);

  model = preset_board_model(drawer_preset);
    // Board data (same extraction as drawer.scad)
  board = preset_board_model(drawer_preset);
  nat_w = get_natural_board_width(board);
  nat_d = get_natural_board_depth(board);
  effective_w = preset_effective_width(board);
  effective_d = preset_effective_depth(board);
  rot = get_board_rotation(board);
  x_offset = preset_x_offset(drawer_preset);
  y_offset = preset_y_offset(drawer_preset);
  z_offset = preset_z_offset(drawer_preset);
  standoff_z = preset_standoff_z_offset(drawer_preset);
  front_board_x = preset_drawer_front_board_x_offset(drawer_preset);
  front_board_y = preset_drawer_front_board_y_offset(drawer_preset);

  totalWidth = effective_w;
  firstBoardCenterX = (body_width - totalWidth)/2 + effective_w/2 + x_offset;

  // Calculate CENTER positions (same formula as drawer.scad, 1 board on body_width)
  bcx = (body_width - effective_w) / 2 + effective_w / 2 + x_offset;
  bcy = effective_d / 2 + y_offset;
  bcz = z_offset + wall_thickness + standoff_z;

  difference() {
    sectionBackBottomBase();

    snap_width=body_width/3;
    intersection() {
      translate([snap_width - 1, 9 + OVERLAP, body_height - 1 + EPS - 2.5 + 0.5])
      cube([snap_width + 2, 1, 1]);
      translate([snap_width - 1, 9 + OVERLAP + 1, body_height - 1.5 + EPS - 2 + 0.4])
      rotate([45, 0, 0])
      cube([snap_width + 2, 1.5, 1.5]);
    }

    translate([body_width, back_depth, 0]) {
      rotate([0, 0, 180]) {
        translate([0, 0, -EPS]) {
          translate([firstBoardCenterX, wall_thickness + bcy, wall_thickness]) { 
            rotate(rot) {
              translate([-nat_w / 2 + front_board_x, -nat_d / 2 + front_board_y, 0]) {
                holes = get_sbcMountingHoles(model);
                // pilot_d = get_screw_spec("M2.5-4", "pilot_hole_diameter");
                // outer_d_top = pilot_d + support_pillar_inset;
                separationZlevel = drawer_board == "rock5b+" ? 35 : 22;
                for (i = [0:len(holes) - 1]) {
                  hole = holes[i];

                  // Check if hole has Z offset (3D position)
                  hole_z_offset = len(hole) > 2 ? hole[2] : 0;
                  pillar_h = bcz + hole_z_offset - wall_thickness + OVERLAP;

                  // We should add a pin to the top part
                  pin_width=3.4;
                  pin_height=7;
                  norm_offset=norm([pin_width, pin_width, 0]);
                  translate([hole[0], hole[1] - norm_offset/2, separationZlevel - pin_height + EPS])
                  rotate([0, 0, 45])
                  cube([pin_width, pin_width, pin_height]);
                }
              }
            }
          }
        }
      }
    }
  }

  difference() {
    translate([body_width, back_depth, 0]) {
      rotate([0, 0, 180]) {
        union() {
          // Mounting supports
          translate([0, 0, -EPS])
          intersection() {
            translate([firstBoardCenterX, wall_thickness + bcy, wall_thickness])
              rotate(rot)
                translate([-nat_w / 2 + front_board_x, -nat_d / 2 + front_board_y, 0])
                  sbcMountingSupports(board, bcz, rot, body_height, "bottom");

            translate([0, 0, (-body_width + body_height)/2])
            honeycomb_box(body_width, back_depth);
          }
        }
      }
    }
  }

  difference() {
    union() {
      // Bottom center
      translate([body_width/2, 0, wall_thickness])
      rotate([0, 0, 0])
      back_mounting_bracket();
    }

    translate([0, -wall_thickness - 3, 0])
    frontfaceMountingHolesFront(type="back", body_height=body_height);
  }

  difference() {
    translate([body_width/2, back_depth - back_face_thickness, wall_thickness])
    rotate([0, 0, 180])
    back_mounting_bracket();

    translate([body_width, back_depth - back_face_thickness + EPS, 0])
    rotate([0, 0, 180])
    frontfaceMountingPattern(body_height)
    screw_hole_mask("M3-10", "back");
  }
}

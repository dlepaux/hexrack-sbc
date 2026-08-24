include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/fan.scad>
use <../../components/drawers.scad>
use <../../components/mounting-holes.scad>

use <../../SBC_Model_Framework/sbc_models.scad>
include <../../SBC_Model_Framework/sbc_models.cfg>

use <../../lib/sbc-helpers.scad>
use <../../lib/pironman-base.scad>

module sectionDust(depth=4 - OVERLAP) {
  body_height = hex_flat_to_flat(body_width-tolerance);
  size = body_width - tolerance;

  // Calculate inner hex dimensions for honeycomb_box_inner_twice
  inner_size = size - 4 * wall_thickness / cos(30);
  hex_flat_height = inner_size * cos(30);
  hex_center_z = size / 2;
  hex_top_z = hex_center_z + hex_flat_height / 2;
  hex_bottom_z = hex_center_z - hex_flat_height / 2;

  cut_amount = 0;  // How much to cut from top and bottom
  union() {
    translate([0, 0, (-(body_width-tolerance) + body_height)/2 + tolerance/2]) {
      difference() {
        // Outer cutout shape
        honeycomb_box_inner((body_width-tolerance), depth, wall_thickness);

        // Inner cutout - with top/bottom trimmed
        translate([0, -1, 0])
        honeycomb_box_inner_twice((body_width-tolerance), wall_thickness, 6.8);

        glue_depth=0.32;
        translate([0, depth - glue_depth + EPS, 0])
        honeycomb_box_inner_twice((body_width-tolerance), glue_depth, 6.8 - 2);
      }
    }

    cube_width=30;
    cube_length=1.7;
    // Bottom
    translate([0, depth - sqrt(cube_length^2 + cube_length^2), wall_thickness + tolerance/2])
    rotate([45, 0, 0])
    union() {
      translate([body_width/2 - cube_width/2, 0, 0])
      rotate([0, 90, 0])
      cube([cube_length, cube_length, cube_width]);
    }

    // Top
    translate([0, depth - sqrt(cube_length^2 + cube_length^2), body_height - (wall_thickness - tolerance/2)])
    rotate([45, 0, 0])
    union() {
      translate([body_width/2 - cube_width/2, 0, 0])
      rotate([0, 90, 0])
      cube([cube_length, cube_length, cube_width]);
    }
  }
}

include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/fan.scad>
use <../../components/drawers.scad>
use <../../components/mounting-holes.scad>

use <../../SBC_Model_Framework/sbc_models.scad>
include <../../SBC_Model_Framework/sbc_models.cfg>

use <../../lib/sbc-helpers.scad>
use <../../lib/pironman-base.scad>

module sectionDust(depth=2) {
  body_height = hex_flat_to_flat(body_width-tolerance);
  size = body_width - tolerance;
  
  // Calculate inner hex dimensions for honeycomb_box_inner_twice
  inner_size = size - 4 * wall_thickness / cos(30);
  hex_flat_height = inner_size * cos(30);
  hex_center_z = size / 2;
  hex_top_z = hex_center_z + hex_flat_height / 2;
  hex_bottom_z = hex_center_z - hex_flat_height / 2;
  
  cut_amount = 8;  // How much to cut from top and bottom

  translate([0, 0, (-(body_width-tolerance) + body_height)/2 + tolerance/2]) {
    difference() {
      // Outer cutout shape
      honeycomb_box_inner((body_width-tolerance), depth, wall_thickness);

      // Inner cutout - with top/bottom trimmed
      difference() {
        translate([0, -1, 0]) 
        honeycomb_box_inner_twice((body_width-tolerance), wall_thickness, wall_thickness);

        // Bottom - block to keep material (cut from hex)
        translate([0, -2, hex_bottom_z])
        cube([body_width, depth + 4, cut_amount]);

        // Top - block to keep material (cut from hex)
        translate([0, -2, hex_top_z - cut_amount])
        cube([body_width, depth + 4, cut_amount]);
      }

      // Bottom - cut through bottom bar for screw clearance
      translate([0, -2, 0])
      cube([body_width, depth + 4, hex_bottom_z + 1.5]);

      // Top - cut through top bar for screw clearance
      translate([0, -2, hex_top_z - 1.5])
      cube([body_width, depth + 4, size - hex_top_z + cut_amount + 10]);
    }
  }
}

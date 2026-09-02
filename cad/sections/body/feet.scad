include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/fan.scad>
use <../../components/drawers.scad>
use <../../components/mounting-holes.scad>

use <../../SBC_Model_Framework/sbc_models.scad>
include <../../SBC_Model_Framework/sbc_models.cfg>

use <../../lib/sbc-helpers.scad>
use <../../lib/pironman-base.scad>

module sectionFeet() {
  body_height = hex_flat_to_flat(body_width);

  // Calibration, not a tidy-uppable magic number: it is what lands the trunk on the floor
  // plane. A foot bridges the half-column offset between staggered units -- body-feet.stl
  // spans Z -64.948..+1.00 against a half case height of 64.952, so it drops the offset it
  // has to bridge to within 0.004mm. Derived from the printed geometry, not from theory;
  // change it only against a measured part.
  adjustement = 4.79;

  // Full assembly depth (face + fan + back)
  full_depth = face_depth + fan_depth + back_depth;
  
  // Diamond head - aligned with female part in back-bottom
  // Female part is at back_depth/2 within back section, which starts at face_depth + fan_depth
  diamond_side_width = 29.5;
  diamond_y = face_depth + fan_depth + back_depth/2 - norm([diamond_side_width, diamond_side_width, 2])/2;
  
  translate([body_width/2, diamond_y, -1])
  rotate([0, 0, 45])
  cube([diamond_side_width, diamond_side_width, 2]);

  // Support
  support_width = diamond_side_width*2.25;
  support_depth = diamond_side_width*4;
  support_center_y = full_depth / 2;

  difference() {
    union() {
      // Feet parameters
      foot_height = body_height/2 - adjustement;

      // Tree trunk foot
      translate([0, 20, 0]) {
        extra=10;
        translate([body_width/2, support_center_y, -2 - (foot_height)])
        resize([support_width*1.5, support_depth * 1.25, foot_height + extra], auto=true)
        import("../../assets/TreeTrunk.stl", convexity=3);

        // Cylinder foot
        translate([body_width/2, support_center_y, -2 - foot_height])
        resize([support_width * 0.68, support_depth * 0.63, foot_height + extra], auto=true)
        cylinder(h=foot_height, r=support_width/2.25, $fn=64);
      }
    }

    translate([body_width/2 - support_width/2 - 25, support_center_y - support_depth/2 - 25, 0])
    rotate([0, 0, 0])
    cube([support_width + 50, support_depth + 50, 50]);
  }
}

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

module sectionBackTopBase() {
  // // Mask
  body_height = hex_flat_to_flat(body_width);

  difference() {
    union() {
      intersection() {
        translate([0, 0, (-body_width + body_height)/2])
        honeycomb_shell(body_width, back_depth, wall_thickness);

        difference() {
          translate([-OVERLAP/2, -OVERLAP/2, body_height/2])
          cube([body_width + OVERLAP, back_depth + OVERLAP, body_height/2 + OVERLAP]);
        }
      }

      intersection() {
        // Male
        translate([0, -3 + EPS, (-body_width + body_height)/2])
        honeycomb_shell(body_width, 3, 1.2);

        difference() {
          translate([-OVERLAP/2, -OVERLAP/2 - 3, body_height/2])
          cube([body_width + OVERLAP, back_depth + OVERLAP, body_height/2 + OVERLAP]);
        }
      }
    }

    extra_female = EPS;
    translate([-extra_female/2, back_depth - 3 + extra_female/2, (-body_width + body_height)/2 - extra_female/2])
    honeycomb_shell(body_width + extra_female, 3, 1.3);

    // Left rail
    translate([dovetail_rail_base_width/2 + dovetail_offset_x, -EPS, body_height/2 - EPS + dovetail_rail_penetration + OVERLAP * 2])
    dovetailRail("bottom", back_depth - 9);

    // Right rail
    translate([body_width + dovetail_rail_base_width/2 - dovetail_offset_x, -EPS, body_height/2 - EPS + dovetail_rail_penetration + OVERLAP * 2])
    dovetailRail("bottom", back_depth - 9);
  }

  // // Mask to plug the modules together
  // diamond_side_width = 29.5;
  // translate([body_width/2, back_depth/2 - norm([diamond_side_width, diamond_side_width, 2])/2, body_height - 1])
  // rotate([0, 0, 45])
  // cube([diamond_side_width, diamond_side_width, 2]);

  // // Left side diamond for horizontal stacking
  // translate([body_width/8, back_depth/2, 3*body_height/4])
  // rotate([0, -60, 0])
  // rotate([0, 0, 45])
  // cube([diamond_side_width, diamond_side_width, 2], center=true);

  // // Right side diamond for horizontal stacking
  // translate([7*body_width/8, back_depth/2, 3*body_height/4])
  // rotate([0, 60, 0])
  // rotate([0, 0, 45])
  // cube([diamond_side_width, diamond_side_width, 2], center=true);

  // Intercase dovetails. Males on every face this case presents upward or sideways;
  // the matching grooves live on the neighbouring case's back-bottom. See
  // dovetailIntercase() in components/dovetails.scad for the frame and clearance math.
  for (face = ["top", "top-right", "top-left"]) {
    if (contains(dovetail_intercase, face)) {
      dovetailIntercase(face, "male", body_height, 1.1, undef, -3.1);
    }
  }
}

module sectionBackTop() {
  body_height = hex_flat_to_flat(body_width);

  difference() {
    union() {
      difference() {
        union() {
          sectionBackTopBase();

          translate([body_width/2, 0, body_height - wall_thickness])
          rotate([0, 180, 0])
          back_mounting_bracket();
        }

        translate([0, -wall_thickness - 3, 0])
        frontfaceMountingHolesFront(type="back", body_height=body_height);
      }

      difference() {
        translate([body_width/2, back_depth - back_face_thickness, body_height - wall_thickness])
        rotate([0, 180, 180])
        back_mounting_bracket();

        translate([body_width, back_depth - back_face_thickness + EPS, 0])
        rotate([0, 0, 180])
        frontfaceMountingPattern(body_height)
        screw_hole_mask("M3-10", "back");
      }
    }
  }
}

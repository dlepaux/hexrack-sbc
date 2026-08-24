include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/fan.scad>
use <../../components/drawers.scad>
use <../../components/mounting-holes.scad>

use <../../SBC_Model_Framework/sbc_models.scad>
include <../../SBC_Model_Framework/sbc_models.cfg>

use <../../lib/sbc-helpers.scad>
use <../../lib/pironman-base.scad>

module sectionFace() {
  body_height = hex_flat_to_flat(body_width);

  difference() {
    translate([0, 0, (-body_width + body_height)/2])
    honeycomb_shell(body_width, face_depth, wall_thickness);

    cube_width=30 + tolerance*2;
    cube_length=1.7;
    // Bottom
    translate([0, face_depth - 2 - sqrt(cube_length^2 + cube_length^2), wall_thickness])
    rotate([45, 0, 0])
    union() {
      translate([body_width/2 - cube_width/2, 0, 0])
      rotate([0, 90, 0])
      cube([cube_length, cube_length, cube_width]);
    }

    // Top
    translate([0, face_depth - 2 - sqrt(cube_length^2 + cube_length^2), body_height - (wall_thickness)])
    rotate([45, 0, 0])
    union() {
      translate([body_width/2 - cube_width/2, 0, 0])
      rotate([0, 90, 0])
      cube([cube_length, cube_length, cube_width]);
    }
  }

  difference() {
    union() {
      translate([0, face_depth - face_thickness, 0])
      difference() {
        translate([0, 0, (-body_width + body_height)/2])
        honeycomb_box(body_width, face_thickness);

        // Voronoi pattern cutout
        // SVG is 2000x2000, scale to fit hex face (body_width point-to-point)
        svg_size = 2000;
        scale_factor = body_width / svg_size * 2;

        translate([0, 0, -100])
        translate([body_width / 2, -EPS, 0])
        rotate([-90, 0, 0])
        linear_extrude(face_thickness + 2*EPS)
          scale([scale_factor, scale_factor])
            translate([-svg_size / 2, -svg_size / 2])
              import("../../assets/voronoi_svg.svg");
      }

      translate([0, face_depth, 0])
      frontfaceMountingPattern(body_height)
      cylinder(h = face_thickness, d = 16);
    }

    #translate([0, -OVERLAP + face_thickness + 1, 0])
    frontfaceMountingHolesFront(type="front", body_height=body_height);
  }
}

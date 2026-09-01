include <../../config.scad>
use <../../lib/shapes.scad>
use <../../lib/vent-patterns.scad>
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
    union() {
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
          translate([0, face_depth - face_thickness, 0]) {
            difference() {
              translate([0, 0, (-body_width + body_height)/2])
              honeycomb_box(body_width, face_thickness);

              // Decorative ventilation. Which pattern is cut is face_vent_pattern;
              // the cutter places itself against this same hexagon footprint.
              ventPatternCutter(body_width, face_thickness);
            }

            // Front circle. Added after the pattern cutout so it refills the cells it
            // crosses, tracing a circle through the pattern instead of opening a bore.
            // Concentric with the fan behind it, hence the shared diameter.
            if (enable_front_circle) {
              translate([0, 0, 0])
              intersection() {
                translate([0, 0, (-body_width + body_height)/2])
                honeycomb_box(body_width, 2, 0);

                translate([0, 0, (-body_width + body_height)/2])
                roundedPanel(
                  body_width,
                  wall_thickness,
                  corner_radius,
                  0,
                  center_hole=fan_size_mode
                );
              }
            }
          }

          translate([0, face_depth, 0])
          frontfaceMountingPattern(body_height)
          cylinder(h = face_thickness, d = 16);
        }

        #translate([0, -OVERLAP + face_thickness + 1, 0])
        frontfaceMountingHolesFront(type="front", body_height=body_height);
      }
    }

    // Female
    honeycombLipFemale(face_depth);
  }
}

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

  // The panel sits at the BACK of the face section, so a pattern that needs a deeper
  // panel grows forward into the plenum instead of moving the case's front face.
  // Module scope, not the union's: the mounting-hole mask below reads it too.
  panel_t = face_panel_thickness();

  // The front circle is the boundary between the solid rim and the vented centre, so it
  // has to stay inside the hexagon: past the flats there is no panel left to carry the
  // rim, and the "circle" silently becomes the whole face.
  //
  // This guard is why front_circle_diameter exists as a parameter at all. It used to be
  // dead -- the intersection below hardcoded fan_size_mode -- so setting it did nothing
  // and an out-of-range value rendered clean. scripts/test-front-circle.sh checks it.
  assert(!enable_front_circle || front_circle_diameter < body_height,
         str("front_circle_diameter ", front_circle_diameter,
             " must be under the face's ", body_height, "mm flat-to-flat height"));

  difference() {
    union() {
      difference() {
        translate([0, 0, (-body_width + body_height)/2])
        honeycomb_shell(body_width, face_depth, wall_thickness);

        cube_width=30 + tolerance*2;
        cube_length=dust_clip_length;
        // Bottom
        translate([0, dust_clip_y + dust_clip_clearance, wall_thickness])
        rotate([45, 0, 0])
        union() {
          translate([body_width/2 - cube_width/2, 0, 0])
          rotate([0, 90, 0])
          cube([cube_length, cube_length, cube_width]);
        }

        // Top
        translate([0, dust_clip_y + dust_clip_clearance, body_height - (wall_thickness)])
        rotate([45, 0, 0])
        union() {
          translate([body_width/2 - cube_width/2, 0, 0])
          rotate([0, 90, 0])
          cube([cube_length, cube_length, cube_width]);
        }
      }

      difference() {
        union() {
          translate([0, face_depth - panel_t, 0]) {
            difference() {
              translate([0, 0, (-body_width + body_height)/2])
              honeycomb_box(body_width, panel_t);

              // Decorative ventilation. Which pattern is cut is face_vent_pattern;
              // the cutter places itself against this same hexagon footprint.
              //
              // The front circle is a CLIP on this cutter, not a solid unioned over the
              // result -- see ventPatternCutter() for why that union had to go.
              ventPatternCutter(body_width, panel_t,
                                circle_diameter = enable_front_circle
                                                    ? front_circle_diameter : 0);
            }
          }

          translate([0, face_depth, 0])
          frontfaceMountingPattern(body_height)
          cylinder(h = panel_t, d = 16);
        }

        #translate([0, -OVERLAP + panel_t + 1, 0])
        frontfaceMountingHolesFront(type="front", body_height=body_height);
      }
    }

    // Female
    honeycombLipFemale(face_depth);
  }
}

include <../../config.scad>
use <../../lib/shapes.scad>
use <../../lib/vent-patterns.scad>
use <../../components/fan.scad>
use <../../components/drawers.scad>
use <../../components/mounting-holes.scad>
use <../../components/antennas.scad>
use <../../components/dovetails.scad>

use <../../SBC_Model_Framework/sbc_models.scad>
include <../../SBC_Model_Framework/sbc_models.cfg>

use <../../lib/sbc-helpers.scad>
use <../../lib/pironman-base.scad>

module sectionBackFace() {
  body_height = hex_flat_to_flat(body_width);
  hex_z_offset = (-body_width + body_height) / 2;

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

  exc_zone = get_exclusion_zone(board);
  exc_z_offset = exc_zone[0]; // Offset from board_z
  exc_x_offset = exc_zone[1]; // Offset from board_z
  exc_height = exc_zone[2]; // Height of exclusion zone
  exc_w = exc_zone[3]; // Width of exclusion zone

  // Calculate CENTER positions (same formula as drawer.scad, 1 board on body_width)
  bcx = (body_width - effective_w) / 2 + effective_w / 2 + x_offset;
  bcy = effective_d / 2 + y_offset;
  bcz = z_offset + wall_thickness + standoff_z;

  difference() {
    union() {
      // Main shell
      translate([0, 0, (-body_width + body_height)/2])
      honeycomb_shell(body_width, back_face_thickness, wall_thickness);

      // Male
      translate([0, -3, (-body_width + body_height)/2])
      honeycomb_shell(body_width, 3, 1.2);

      translate([0, 0, 0])
      difference() {
        union() {
          difference() {
            translate([0, 0, hex_z_offset + 0])
            honeycomb_box(body_width, back_face_thickness);

            // Voronoi pattern cutout with exclusion zone
            difference() {
              // Decorative ventilation. Which pattern is cut is face_vent_pattern;
              // the cutter places itself against this same hexagon footprint.
              ventPatternCutter(body_width, back_face_thickness);

              // Create exclusion zone for each board
              if (board != undef && exc_height > 0 && exc_w > 0) {
                exc_radius = 4;
                translate([body_width / 2 + exc_x_offset, 0 - EPS, bcz + exc_z_offset + exc_height / 2])
                  rotate([-90, 0, 0])
                    linear_extrude(back_face_thickness + 4 * EPS)
                      offset(r=exc_radius, $fn=30)
                        square([exc_w - 2 * exc_radius, exc_height - 2 * exc_radius], center=true);
              }
            }
          }

          intersection() {
            translate([0, 0, hex_z_offset + 0])
            honeycomb_box(body_width, back_face_thickness);

            translate([0, 0 + back_face_thickness, 0])
            frontfaceMountingPattern(body_height)
            cylinder(h = back_face_thickness, d = 16);
          }

          // Antenna reinforcement pads — fill voronoi cutouts around each
          // antenna hole so the panel has continuous material to grip the post.
          if (enable_wifi_antennas) {
            intersection() {
              translate([0, 0, hex_z_offset + 0])
              honeycomb_box(body_width, back_face_thickness);

              for (sx = [-1, 1]) {
                translate([body_width / 2 + sx * antenna_x_spread / 2,
                           0 + back_face_thickness,
                           body_height / 2])
                  rotate([90, 0, 0])
                    cylinder(h = back_face_thickness, d = antenna_pad_diameter, $fn = 60);
              }
            }
          }
        }

        // Apply all connector masks for SBC - using center-based positioning
        if (board != undef) {
          translate([body_width, 0, 0]) {
            rotate([0, 0, 180]) {
              translate([firstBoardCenterX, wall_thickness + bcy, bcz]) {
                rotate(rot) {
                  translate([-nat_w / 2 + front_board_x, -nat_d / 2 + front_board_y, 0]) {
                    if (isPironman(board)) {
                      pironmanBase(enablemask=true);
                    } else {
                      sbc(model=board, enablemask=true);
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    translate([body_width, back_face_thickness + EPS, 0])
    rotate([0, 0, 180])
    frontfaceMountingPattern(body_height)
    screw_hole_mask("M3-10", "front");

    // WiFi antenna holes — symmetric around body_width/2.
    // Outside face of panel is at y = 0; mask local +Z = out-of-case.
    if (enable_wifi_antennas) {
      for (sx = [-1, 1]) {
        translate([body_width / 2 + sx * antenna_x_spread / 2, 0 - antenna_nut_thickness, body_height/2])
          rotate([-90, 0, 0])
            antenna_hole_mask();
      }
    }

    // Carry the intercase dovetail channels straight through this panel and its front
    // lip. Without it the lip refills the last 3mm of every groove in back-bottom, so a
    // neighbouring case's rail cannot enter and the panel has to come off to assemble.
    // Spans the panel (y 0..back_face_thickness) plus the lip (y -3..0), EPS either end.
    for (face = ["bottom", "bottom-left", "bottom-right"]) {
      if (contains(dovetail_intercase, face)) {
        dovetailIntercase(face, "female", body_height,
                          -3 - EPS, back_face_thickness + 3 + 2 * EPS);
      }
    }
  }

  // WiFi antenna visualization — preview only, not subtracted.
  if (enable_wifi_antennas && show_antennas) {
    for (sx = [-1, 1]) {
      #translate([body_width / 2 + sx * antenna_x_spread / 2, 0 - antenna_nut_thickness, body_height/2])
        rotate([-90, 0, 0])
          antenna_visualization();
    }
  }
}

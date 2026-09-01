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

module sectionTopSupports() {
  body_height = hex_flat_to_flat(body_width);

  difference() {
    union() {
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

      translate([body_width, back_depth, 0]) {
        rotate([0, 0, 180]) {
          union() {
            // SBC
            if (show_sbc) {
              translate([firstBoardCenterX, wall_thickness + bcy, bcz])
                rotate(rot)
                  translate([-nat_w / 2 + front_board_x, -nat_d / 2 + front_board_y, 0]) {
                    if (isPironman(board)) {
                      pironmanBase(enablemask=false);
                    } else {
                      sbc(model=board, enablemask=false);
                    }
                  }
            }
          }
        }
      }
    }
  }
}

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
    union() {
      translate([0, 0, (-body_width + body_height)/2])
      honeycomb_shell(body_width, back_depth, wall_thickness);

      // Male
      honeycombLipMale();
    }

    // Female
    honeycombLipFemale(back_depth);

    // Half-section trim: back-bottom is the lower half, so everything above the
    // split plane goes. It has to start early enough and run long enough to span
    // the male tongue as well -- lipMaleLength(), not lip_depth, because the
    // tongue now reaches past the rebate and down the female's ramp. Short of
    // that, the tongue's tip keeps its upper half and fouls back-top's.
    translate([-OVERLAP/2, -OVERLAP/2 - lipMaleLength(), body_height/2])
    cube([body_width + OVERLAP, back_depth + OVERLAP + lipMaleLength(),
          body_height/2 + OVERLAP]);

    // Intercase dovetail grooves. Each receives the male rail of the neighbouring case
    // that presents the same plane: "bottom" takes the case below's "top", "bottom-left"
    // takes the down-left neighbour's "top-right", "bottom-right" its "top-left".
    for (face = ["bottom", "bottom-left", "bottom-right"]) {
      if (contains(dovetail_intercase, face)) {
        dovetailIntercase(face, "female", body_height, 1);
      }
    }
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
  support_mandatory_standoff_height = preset_support_mandatory_standoff_height(drawer_preset);

  totalWidth = effective_w;
  firstBoardCenterX = (body_width - totalWidth)/2 + effective_w/2 + x_offset;

  // This section is modelled from its far corner, so everything board-related
  // lives inside a 180-degree flip. Both frames were previously spelled out at
  // each use, which is how the female cutter at the end of the supports block
  // came to sit outside the flip while looking like it was inside it.
  module inSectionFrame(z = 0) {
    translate([body_width, back_depth, z])
      rotate([0, 0, 180])
        children();
  }

  // The board's own origin, within that flipped frame.
  module onBoard() {
    translate([firstBoardCenterX, wall_thickness + bcy, wall_thickness])
      rotate(rot)
        translate([-nat_w / 2 + front_board_x, -nat_d / 2 + front_board_y, 0])
          children();
  }

  // Calculate CENTER positions (same formula as drawer.scad, 1 board on body_width)
  bcx = (body_width - effective_w) / 2 + effective_w / 2 + x_offset;
  bcy = effective_d / 2 + y_offset;
  bcz = z_offset + wall_thickness + standoff_z;

  // One positive, one set of cutters. This used to be four sibling blocks that
  // were implicitly unioned, and because difference() only cuts its first child,
  // each block had to repeat the cutters it needed -- the female lip, the front
  // mounting holes and the rear screw pattern each appeared twice, in two
  // different coordinate frames. Keep new cutters in this one list.
  difference() {
    union() {
      sectionBackBottomBase();

      // Mounting supports, clipped to the section's hexagonal bore.
      inSectionFrame()
        intersection() {
          onBoard()
            sbcMountingSupports(board, bcz, rot, body_height, support_mandatory_standoff_height);

          translate([0, 0, (-body_width + body_height)/2])
          honeycomb_box(body_width, back_depth);
        }

      translate([body_width/2, 0, wall_thickness])
      back_mounting_bracket();

      translate([body_width/2, back_depth, wall_thickness])
      rotate([0, 0, 180])
      back_mounting_bracket();
    }

    // Snap detent along the top edge: a 1mm notch chamfered by a 45-degree cube.
    snap_width = body_width/3;
    intersection() {
      translate([snap_width - 1, 9 + OVERLAP, body_height - 1 + EPS - 2.5 + 0.5])
      cube([snap_width + 2, 1, 1]);

      translate([snap_width - 1, 9 + OVERLAP + 1, body_height - 1.5 + EPS - 2 + 0.4])
      rotate([45, 0, 0])
      cube([snap_width + 2, 1.5, 1.5]);
    }

    // Insert pockets, at the top of each support. Shares sbcSupportTopZ with the
    // bosses themselves so the two cannot drift apart; rides EPS low so a pocket
    // always breaks through instead of leaving a skin.
    inSectionFrame(-EPS)
      onBoard()
        for (hole = get_sbcMountingHoles(board)) {
          translate([hole[0], hole[1],
                     sbcSupportTopZ(hole, bcz, wall_thickness, support_mandatory_standoff_height)])
          insert_hole_mask("M2.5");
        }

    // Female
    honeycombLipFemale(back_depth);

    translate([0, -wall_thickness - 3, 0])
    frontfaceMountingHolesFront(type="back", body_height=body_height);

    translate([body_width, back_depth + EPS, 0])
    rotate([0, 0, 180])
    frontfaceMountingPattern(body_height)
    screw_hole_mask("M3-10", "back");
  }
}

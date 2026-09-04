// ============================================================================
// SETUP - Board offset tuning harness
// ============================================================================
// Renders ONE unit's board exactly where the real sections put it, inside a
// cutaway of the bore it has to live in, so the preset offsets can be tuned by
// eye instead of by rendering a whole case and squinting at it.
//
// PROVENANCE. config.scad has referenced this file since the first commit ("Use
// setup.scad to visually configure offset values") while no such file existed here: it
// is in no tree of this repo, no reflog entry and no dangling object. It was never lost
// from hexrack-sbc -- it was never IN hexrack-sbc. The original belonged to this
// project's ancestor, WebServer/raspberry-pi-mini-rack, and came across as a comment
// when the CAD was forked. Siblings existed in raspberry-pi-mini-rack2 and megafan-200.
// All three working copies are gone; the only surviving trace is VS Code's local
// history, under ~/Library/Application Support/Code/User/History (folders -65063750,
// 80f3ce4 and 193d6b0, indexed by entries.json).
//
// The alignment aids below -- grid, axis markers, dimensioned bounding box, and the
// paste-ready preset dump -- are restored from that original. The case-frame views
// (cutaway/section/overflow) and the fit envelope are new.
//
// THE INVARIANT: the board frame below is copied from sections/body/back-bottom.scad
// and MUST stay identical to it. If the two drift, this harness cheerfully shows a
// board that fits while the printed case does not. bodyFrame()/onBoard() are
// deliberately verbatim rather than "improved" for that reason. The numeric check
// that the two agree is scripts/test-board-fit.sh, which drives this file.
//
// Usage:
//   openscad cad/setup.scad -D 'drawer_board="bitaxe_naja_duo"'
//
//   setup_view = "cutaway"  half the bore removed, board in place (default)
//   setup_view = "section"  the real back-bottom section, board ghosted over it
//   setup_view = "board"    board alone, no case
//   setup_view = "align"    board at the ORIGIN with grid, axes and a dimensioned
//                           bounding box -- the view for aligning and rotating a new
//                           STL asset and checking its scale
//   setup_view = "overflow" board envelope MINUS the bore; empty means it fits
//                           (this is what scripts/test-board-fit.sh renders)
// ============================================================================

include <config.scad>
use <lib/shapes.scad>
use <lib/sbc-helpers.scad>
use <lib/pironman-base.scad>
// include, not use: the envelope below needs this file's constants, and
// `use` imports only modules and functions.
include <lib/naja-duo-base.scad>
use <sections/body/back-bottom.scad>

use <SBC_Model_Framework/sbc_models.scad>
include <SBC_Model_Framework/sbc_models.cfg>

setup_view = "cutaway";
setup_show_holes = true;   // mark each mounting hole with a pin through the board
setup_show_bore = true;    // outline the hexagonal bore the stack must clear
setup_show_grid = true;    // 10mm grid on the XY plane ("align" view)
setup_show_axes = true;    // X red / Y green / Z blue ("align" view)
setup_show_bbox = true;    // dimensioned bounding box ("align" view)
setup_show_masks = false;  // overlay the connector masks on the visual

body_height = hex_flat_to_flat(body_width);

// ============================================================================
// BOARD FRAME -- copied from sections/body/back-bottom.scad
// ============================================================================
board        = preset_board_model(drawer_preset);
nat_w        = get_natural_board_width(board);
nat_d        = get_natural_board_depth(board);
effective_w  = preset_effective_width(board);
effective_d  = preset_effective_depth(board);
rot          = get_board_rotation(board);
x_offset     = preset_x_offset(drawer_preset);
y_offset     = preset_y_offset(drawer_preset);
z_offset     = preset_z_offset(drawer_preset);
standoff_z   = preset_standoff_z_offset(drawer_preset);
front_board_x = preset_drawer_front_board_x_offset(drawer_preset);
front_board_y = preset_drawer_front_board_y_offset(drawer_preset);
mandatory_standoff = preset_support_mandatory_standoff_height(drawer_preset);

bcx = (body_width - effective_w) / 2 + effective_w / 2 + x_offset;
bcy = effective_d / 2 + y_offset;
bcz = z_offset + wall_thickness + standoff_z;

// back-bottom models itself from its far corner; everything board-related lives
// inside this flip.
module inSectionFrame(z = 0) {
  translate([body_width, back_depth, z])
    rotate([0, 0, 180])
      children();
}

module onBoard() {
  translate([bcx, wall_thickness + bcy, wall_thickness])
    rotate(rot)
      translate([-nat_w / 2 + front_board_x, -nat_d / 2 + front_board_y, 0])
        children();
}

// The board itself, in its final place. Same dispatch as top-supports.scad.
module setupBoard() {
  inSectionFrame()
    translate([bcx, wall_thickness + bcy, bcz])
      rotate(rot)
        translate([-nat_w / 2 + front_board_x, -nat_d / 2 + front_board_y, 0]) {
          if (isPironman(board)) {
            pironmanBase(enablemask=false);
          } else if (board == "bitaxe_naja_duo") {
            najaDuoBase(enablemask=false);
          } else {
            sbc(model=board, enablemask=false);
          }
        }
}

module setupSupports() {
  inSectionFrame()
    intersection() {
      onBoard()
        sbcMountingSupports(board, bcz, rot, body_height, mandatory_standoff);

      translate([0, 0, (-body_width + body_height)/2])
        honeycomb_box(body_width, back_depth);
    }
}

// A pin through every mounting hole. The single most useful thing in this file:
// a hole that has drifted off its boss is invisible in a solid render and obvious
// the moment a pin is standing next to a pillar instead of in it.
module setupHolePins() {
  inSectionFrame()
    translate([bcx, wall_thickness + bcy, bcz])
      rotate(rot)
        translate([-nat_w / 2 + front_board_x, -nat_d / 2 + front_board_y, 0])
          for (h = get_sbcMountingHoles(board))
            color("red")
              translate([h[0], h[1], (len(h) > 2 ? h[2] : 0) - 25])
                cylinder(d = 1.6, h = 50, $fn = 16);
}

// ============================================================================
// THE BORE
// ============================================================================
// What the board and everything bolted to it actually has to clear: the inner
// hexagon, drawn as a wireframe so the stack is visible inside it. This is the
// surface the Naja Duo's heatsink very nearly touches, so it is worth seeing.
module setupBore() {
  // honeycomb_box_inner, NOT honeycomb_box at the inner diameter: honeycomb_box
  // self-centres on the size it is given, so passing it the inner size shifts the
  // bore 5.77mm off the shell it is supposed to represent -- which reads as the
  // board hitting a wall it is nowhere near.
  %translate([0, 0, (-body_width + body_height)/2])
    difference() {
      honeycomb_box(body_width, back_depth);
      honeycomb_box_inner(body_width, back_depth, wall_thickness);
    }
}

// ============================================================================
// ALIGNMENT AIDS
// ============================================================================
// Restored from the original setup.scad. That file lived in this project's ancestor
// (raspberry-pi-mini-rack) and was never committed here, which is why config.scad has
// referenced it since the first commit while no such file existed.
//
// This is the half of the tool that matters when a NEW asset arrives: an STL turns up
// in some arbitrary frame, in millimetres or -- as the Coolserver heatsink did -- in
// METRES, and the only way to see it is against a known grid with labelled axes.

module axis_markers(size = 50) {
  color("red",   0.8) hull() { sphere(1, $fn=16); translate([size, 0, 0]) sphere(1, $fn=16); }
  color("green", 0.8) hull() { sphere(1, $fn=16); translate([0, size, 0]) sphere(1, $fn=16); }
  color("blue",  0.8) hull() { sphere(1, $fn=16); translate([0, 0, size]) sphere(1, $fn=16); }
  color("yellow", 0.9) sphere(2, $fn=16);
}

module grid_plane(size = 200, spacing = 10) {
  color("gray", 0.2)
    for (i = [-size/spacing : size/spacing]) {
      translate([0, i * spacing, 0]) cube([size, 0.2, 0.2], center = true);
      translate([i * spacing, 0, 0]) cube([0.2, size, 0.2], center = true);
    }
}

// Wireframe box with the three dimensions written on it, so scale errors are read off
// the model rather than guessed at.
module bounding_box(width, depth, height) {
  color("orange", 0.15)
    translate([-width/2, -depth/2, 0]) {
      for (c = [[0,0],[width,0],[0,depth],[width,depth]])
        translate([c[0], c[1], 0]) cylinder(d = 0.8, h = height, $fn = 8);
      for (z = [0, height]) {
        translate([0, 0,     z]) cube([width, 0.8, 0.8]);
        translate([0, depth, z]) cube([width, 0.8, 0.8]);
        translate([0, 0,     z]) cube([0.8, depth, 0.8]);
        translate([width, 0, z]) cube([0.8, depth, 0.8]);
      }
    }

  color("orange") {
    translate([0, -depth/2 - 10, 0]) rotate([90, 0, 0])
      linear_extrude(0.5) text(str(width, "mm"), size = 5, halign = "center");
    translate([width/2 + 10, 0, 0]) rotate([90, 0, 90])
      linear_extrude(0.5) text(str(depth, "mm"), size = 5, halign = "center");
    translate([width/2 + 10, -depth/2 - 10, height/2]) rotate([0, 90, 0]) rotate([0, 0, 90])
      linear_extrude(0.5) text(str(height, "mm"), size = 5, halign = "center");
  }
}

// The board in ITS OWN frame, centred on the origin -- not in the case. This is the
// frame an asset is authored in, so it is the frame to align one in.
module setupAligned() {
  rotate(rot)
    translate([-nat_w / 2 + front_board_x, -nat_d / 2 + front_board_y, 0]) {
      if (isPironman(board))                   pironmanBase(enablemask = false);
      else if (board == "bitaxe_naja_duo")     najaDuoBase(enablemask = false);
      else                                     sbc(model = board, enablemask = false);

      if (setup_show_masks) {
        if (isPironman(board))                 pironmanBase(enablemask = true);
        else if (board == "bitaxe_naja_duo")   najaDuoBase(enablemask = true);
        else                                   sbc(model = board, enablemask = true);
      }
    }
}

// ============================================================================
// FIT ENVELOPE
// ============================================================================
// A manifold stand-in for everything the board puts inside the case, placed by the
// SAME frame as the visual. This exists because the fit check cannot use the visual:
// assets/BitaxeNajaDuo.stl and the Coolserver mesh are both open surfaces
// ("Input mesh is not closed"), so any difference() against them collapses the whole
// top-level object to empty -- which would make an overflow test pass by rendering
// nothing, the exact false negative a fit test is for.
//
// Every proxy bounds the real part rather than approximating it, so a pass here is a
// real pass. The heatsink is built from naja_duo_heatsink_profile band by band rather
// than as one box: its fins taper from 89.9mm at the base to 65.1mm at the top while
// the hexagon narrows with height too, and a single bounding box reports a collision
// where there is 8.6mm of clearance.
module setupEnvelope() {
  is_naja = board == "bitaxe_naja_duo";

  inSectionFrame()
    translate([bcx, wall_thickness + bcy, bcz])
      rotate(rot)
        translate([-nat_w / 2 + front_board_x, -nat_d / 2 + front_board_y, 0]) {
          if (is_naja) {
            // Two measured profiles, one plate per band, each centred across the
            // board's Y axis -- the axis that crosses the hexagon once the board is
            // rotated. Depth (board X) is unconstrained, so every plate simply spans
            // the board's full length.
            najaDuoBand(naja_duo_pcb_profile, 0);
            najaDuoBand(naja_duo_heatsink_profile, naja_duo_heatsink_datum);
          } else {
            // A framework board declares no envelope, so all this can honestly check
            // is the outline. Nothing standing on a Rock5B+ or a Pironman is tested
            // here -- scripts/test-board-fit.sh says so rather than implying coverage
            // it does not have.
            cube([nat_w, nat_d, 1.6]);
          }
        }
}

// One plate per profile band. `base` is where the profile's z=0 sits above the
// board's bottom face.
module najaDuoBand(profile, base) {
  for (i = [0 : len(profile) - 1]) {
    z0 = profile[i][0];
    w  = profile[i][1];
    z1 = (i < len(profile) - 1) ? profile[i + 1][0] : z0 + 2;
    translate([0, nat_d / 2 - w / 2, base + z0])
      cube([nat_w, w, z1 - z0]);
  }
}

// Everything the envelope puts OUTSIDE the bore. Empty means it fits.
module setupOverflow() {
  difference() {
    setupEnvelope();
    translate([0, 0, (-body_width + body_height)/2])
      honeycomb_box_inner(body_width, back_depth, wall_thickness, 0, 0);
  }
}

// ============================================================================
// VIEWS
// ============================================================================
if (setup_view == "align") {
  if (setup_show_grid) grid_plane();
  if (setup_show_axes) axis_markers();
  setupAligned();
  if (setup_show_bbox) bounding_box(effective_w, effective_d, 50);

} else if (setup_view == "overflow") {
  setupOverflow();

} else if (setup_view == "board") {
  setupBoard();
  setupSupports();
  if (setup_show_holes) setupHolePins();

} else if (setup_view == "section") {
  sectionBackBottom();
  %setupBoard();
  if (setup_show_holes) setupHolePins();
  if (setup_show_bore) setupBore();

} else {
  // cutaway: the near half of the shell removed, so the stack inside is visible
  difference() {
    union() {
      sectionBackBottom();
      color("orange") setupSupports();
    }
    translate([-OVERLAP, -OVERLAP, -OVERLAP])
      cube([body_width / 2 + OVERLAP, back_depth + 2 * OVERLAP,
            body_height + 2 * OVERLAP]);
  }
  setupBoard();
  if (setup_show_holes) setupHolePins();
  if (setup_show_bore) setupBore();
}

// ============================================================================
// CONSOLE OUTPUT
// ============================================================================
// Two blocks, for two different readers.
//
// The first is for a human tuning offsets: the dimensions, the derived board Z, and
// the preset itself laid out one field per line so an adjusted value can be pasted
// straight back into config.scad. Restored from the original tool.
echo("===========================================================");
echo(str("BOARD: ", board, "     rotation ", rot));
echo("===========================================================");
echo(str("  natural   ", nat_w, "mm x ", nat_d, "mm"));
echo(str("  effective ", effective_w, "mm x ", effective_d, "mm   (after rotation)"));
echo(str("  board_z = z_offset + wall_thickness + standoff_z_offset"));
echo(str("          = ", z_offset, " + ", wall_thickness, " + ", standoff_z, " = ", bcz, "mm"));
echo(str("  canoe top sits ", mandatory_standoff, "mm below the board"));
echo(str("  centre in section frame: x ", bcx, "  y ", wall_thickness + bcy));
echo("-----------------------------------------------------------");
echo(str("preset_", board, " = ["));
echo(str("  \"", board, "\", ", preset_height(drawer_preset), ", ", x_offset, ", ", y_offset, ", ", z_offset, ","));
echo(str("  ", standoff_z, ",                    // standoff_z_offset"));
echo(str("  ", front_board_x, ", ", front_board_y, ", ",
         preset_drawer_front_board_mask_x_offset(drawer_preset), ", ",
         preset_drawer_front_board_mask_y_offset(drawer_preset), ","));
echo(str("  ", preset_honeycomb_padding(drawer_preset), ", ",
         preset_honeycomb_padding_top(drawer_preset), ", ",
         preset_honeycomb_padding_bottom(drawer_preset), ", ",
         preset_honeycomb_pattern_z_offset(drawer_preset), ","));
echo(str("  ", mandatory_standoff, ",                    // support_mandatory_standoff_height"));
echo("];");
echo("===========================================================");

// The second is machine-readable, on one line, and is what scripts/test-board-fit.sh
// and any other harness parses. Kept separate from the block above so prettifying the
// human output cannot break a test.
echo(str("HEXRACK_SETUP",
         " board=",        board,
         " naturalW=",     nat_w,
         " naturalD=",     nat_d,
         " effectiveW=",   effective_w,
         " effectiveD=",   effective_d,
         " rotZ=",         rot[2],
         " boardZ=",       bcz,
         " standoff=",     standoff_z,
         " mandatoryStandoff=", mandatory_standoff,
         " backDepth=",    back_depth,
         " bodyWidth=",    body_width,
         " flatToFlat=",   body_height,
         " wall=",         wall_thickness,
         " holes=",        len(get_sbcMountingHoles(board))));

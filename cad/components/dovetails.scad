include <../config.scad>

function getRotation(side) =
  side == "none" ?  [0, 0, 0] :
  side == "front" ?  [0, 0, 0] :
  side == "bottom" ?  [90, 0, 180] :
  side == "left" ?  [90, -90, 180] :
  side == "right" ?  [90, 90, 180] :
  [0, 0, 0];

module dovetailRail(side = "bottom", length, tolerance=0, angle=75, base_width=dovetail_rail_base_width, height=dovetail_rail_height) {
  // Calculate horizontal offset based on angle and height
  offset = height / tan(angle);

  rotate(getRotation(side))
  linear_extrude(height=length)
  polygon([
    [tolerance, 0],  // top left - moved inward
    [offset + tolerance, -height],  // bottom left - moved inward
    [base_width - offset - tolerance, -height],  // bottom right - moved inward
    [base_width - tolerance, 0]  // top right - moved inward
  ]);
}

// ============================================================================
// INTERCASE DOVETAILS
// ============================================================================
// Cases tile like a honeycomb, and each case is split at mid-height into back-top and
// back-bottom. Every face a case can present to a neighbour carries half a dovetail:
// the male stands on this case, the groove is cut into the one it meets.
//
//   this case's face                            the neighbour's face
//   ----------------                            --------------------
//   top             (case directly above)  <->  bottom
//   top-right       (case up and right)    <->  bottom-left
//   top-left        (case up and left)     <->  bottom-right
//
// Because a mating pair is literally the SAME PLANE, the male and its groove are the
// same shape at the same world orientation -- only the anchor midpoint differs. One
// module therefore drives all six faces, and the pair agrees by construction instead
// of by two independently hand-tuned placements.
//
// A regular hexagon's slanted faces rise at 60 degrees from horizontal, so their
// outward normal points 30 degrees off horizontal -- not straight up. Offsetting a rail
// along +Z alone clears only (rail_height * sin 30) and buries the rest in the wall, so
// placement is computed in the face's own frame. The flat top/bottom faces are the same
// formula at 0 degrees.
//
// Clearance follows the back-top/back-bottom split convention: the groove is cut at
// nominal size and the male carries all of it -- narrowed by dovetail_clearance on each
// flank, and set back half a clearance along the normal so it cannot bottom out.

// [face angle from horizontal, mirrored?]. Mating faces share both entries, which is
// exactly what puts a male and its groove on one plane in one orientation.
function intercaseFaceFrame(face) =
    face == "top"          ? [ 0, false]
  : face == "bottom"       ? [ 0, false]
  : face == "top-right"    ? [60, false]
  : face == "bottom-left"  ? [60, false]
  : face == "top-left"     ? [60, true ]
  : face == "bottom-right" ? [60, true ]
  : undef;

// Midpoint [x, z] of a named face on the hexagonal cross-section.
function intercaseFaceMidpoint(face, body_height) = [
    (face == "top-right" || face == "bottom-right") ? 7 * body_width / 8
  : (face == "top-left"  || face == "bottom-left")  ?     body_width / 8
  :                                                       body_width / 2,
    face == "top"                                   ? body_height
  : face == "bottom"                                ? 0
  : (face == "top-right" || face == "top-left")     ? 3 * body_height / 4
  :                                                       body_height / 4
];

// face   - "top" | "bottom" | "top-right" | "top-left" | "bottom-right" | "bottom-left"
// gender - "male" unions onto the face, "female" is meant to be subtracted from it
// body_height - must be hex_flat_to_flat(body_width)
module dovetailIntercase(face, gender, body_height) {
  frame = intercaseFaceFrame(face);
  assert(!is_undef(frame), str("dovetailIntercase: unknown face '", face, "'"));
  assert(gender == "male" || gender == "female",
         str("dovetailIntercase: unknown gender '", gender, "'"));

  angle    = frame[0];
  mirrored = frame[1];
  male     = (gender == "male");
  mid      = intercaseFaceMidpoint(face, body_height);

  base_width = dovetail_rail_base_width_intercase;
  tolerance  = male ? dovetail_clearance : 0;

  // Distance from the face plane out to dovetailRail()'s local origin, i.e. its WIDE
  // plane. EPS keeps the male's root a hair inside the shell and the groove's mouth a
  // hair proud of it, so neither boolean has to resolve coplanar surfaces.
  seat_normal = dovetail_rail_height - EPS - (male ? dovetail_clearance / 2 : 0);
  seat_x = seat_normal * sin(angle) - base_width / 2 * cos(angle);
  seat_z = seat_normal * cos(angle) + base_width / 2 * sin(angle);

  // The groove overruns the section in Y so it breaks out cleanly at both ends.
  y_lo   = male ? 0 : -EPS;
  length = male ? back_depth : back_depth + 2 * EPS;

  translate([mid[0] + (mirrored ? -seat_x : seat_x),
             mirrored ? y_lo : y_lo + length,
             mid[1] + seat_z])
  rotate([0, mirrored ? -angle : angle, 0])
  rotate(mirrored ? [90, 0, 180] : [90, 0, 0])
  dovetailRail("none", length, tolerance, 75, base_width);
}

module dovetailRailMaleBottom(preset, pw, rail_length = drawer_depth - dovetail_stop_distance - drawer_clearance) {
  // Alignment rails for bracket positioning
  rail_x_center = dovetail_rail_base_width/2;
  rail_x_start = corner_bracket_width/2 + dovetail_rail_base_width/2;
  rail_y_start = panel_thickness - OVERLAP;
  rail_z_start = panel_bottom_thickness + dovetail_rail_penetration + OVERLAP * 2 - dovetail_clearance/2;

  show_middle_support = preset_show_middle_support(preset);
  show_dual_middle_support = preset_show_dual_middle_support(preset);
  space_between_dual_middle_support = preset_space_between_dual_middle_support(preset);

  // Middle support rail
  if (show_middle_support) {
    translate([pw/2 + rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("bottom", rail_length, dovetail_clearance);
  }

  // Dual middle support rail
  if (show_dual_middle_support) {
    translate([pw/2 + space_between_dual_middle_support/2 + rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("bottom", rail_length, dovetail_clearance);

    translate([pw/2 - space_between_dual_middle_support/2 + rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("bottom", rail_length, dovetail_clearance);
  }

  if (show_sides_support) {
    // Left rail (under tall bracket)
    translate([rail_x_start, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("bottom", rail_length, dovetail_clearance);
    // Right rail (under tall bracket)
    translate([pw - corner_bracket_width/2 + rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("bottom", rail_length, dovetail_clearance);
  }
}

module dovetailRailMaleFront(preset, pw, ph) {
  rail_length = ph - panel_bottom_thickness * 2;
  rail_x_center = dovetail_rail_base_width/2;
  rail_y_start = panel_thickness + dovetail_rail_penetration + OVERLAP * 2 - dovetail_clearance/2;
  rail_z_start = panel_bottom_thickness * 2;

  show_middle_support = preset_show_middle_support(preset);
  show_dual_middle_support = preset_show_dual_middle_support(preset);
  space_between_dual_middle_support = preset_space_between_dual_middle_support(preset);

  // Middle support rail
  if (show_middle_support) {
    translate([pw/2 - rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("front", rail_length, dovetail_clearance);
  }

  // Dual middle support rail
  if (show_dual_middle_support) {
    translate([pw/2 - space_between_dual_middle_support/2 - rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("front", rail_length, dovetail_clearance);

    translate([pw/2 + space_between_dual_middle_support/2 - rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("front", rail_length, dovetail_clearance);
  }

  if (show_sides_support) {
    // Left rail
    translate([corner_bracket_width/2 - rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("front", rail_length, dovetail_clearance);

    // Right rail
    translate([pw - corner_bracket_width/2 - rail_x_center, rail_y_start, rail_z_start])
    color("orange")
    dovetailRail("front", rail_length, dovetail_clearance);
  }
}

module dovetailRailFemale(base_x, pw, ph) {
  // Bottom rail
  rail_bottom_length = drawer_depth - dovetail_stop_distance;
  rail_bottom_x_start = base_x + dovetail_rail_base_width/2;
  rail_bottom_y_start = panel_thickness - EPS;
  rail_bottom_z_start = panel_bottom_thickness + dovetail_rail_penetration + OVERLAP * 2;

  // Front rail
  rail_front_length = ph;
  rail_front_x_start = base_x - dovetail_rail_base_width/2;
  rail_front_y_start = panel_thickness + dovetail_rail_penetration + OVERLAP * 2;
  rail_front_z_start = panel_bottom_thickness + dovetail_rail_height;

  difference() {
    union() {
      // Bottom rail cutout
      translate([rail_bottom_x_start, rail_bottom_y_start, rail_bottom_z_start])
      dovetailRail("bottom", rail_bottom_length);

      // Front rail cutout
      translate([rail_front_x_start, rail_front_y_start, rail_front_z_start])
      dovetailRail("front", rail_front_length);
    }
  }
}

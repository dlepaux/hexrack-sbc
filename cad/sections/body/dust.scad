include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/fan.scad>
use <../../components/drawers.scad>
use <../../components/mounting-holes.scad>

use <../../SBC_Model_Framework/sbc_models.scad>
include <../../SBC_Model_Framework/sbc_models.cfg>

use <../../lib/sbc-helpers.scad>
use <../../lib/pironman-base.scad>

// ============================================================================
// FRONT-FACE LABELS
// ============================================================================
// The dust filter is a hexagonal ring: a solid band between the outer profile
// honeycomb_box_inner() cuts and the inner opening honeycomb_box_inner_twice() takes
// out. At the flats that band is 8.6mm wide, and its top and bottom edges are the only
// flat, unbroken, outward-facing surfaces anywhere on the assembled case.
//
// Engraved from y = 0, which is the case's exposed front: the filter nests in the face
// section's front cavity (the face's own panel sits at its BACK, y = face_depth -
// face_panel_thickness() -- the panel's depth varies by vent pattern, the seat does not).
// The part prints lying flat with this face up, so the text is a top surface -- no
// overhang, no bridging.
//
// Parameters are the ring's two hexagons, in point-to-point diameter, so this cannot
// drift from the profiles the caller actually built.
module dustLabelCutter(outer_p2p, inner_p2p, centre_xz) {
  band_outer = outer_p2p * cos(30) / 2;   // flat-to-flat radius, i.e. centre to a flat
  band_inner = inner_p2p * cos(30) / 2;
  band_width = band_outer - band_inner;

  assert(dust_label_size < band_width,
         str("dust_label_size ", dust_label_size, " does not fit the ",
             band_width, "mm band between the dust filter's hexagons"));

  // Centred in the band, so the same offset serves the top and bottom edges.
  band_mid = (band_outer + band_inner) / 2;

  // text() has no width limit and an overlong label fails SILENTLY: it renders exit-0 as a
  // valid one-body manifold whose bounding box is byte-identical to the blank part, because
  // glyphs running past the flat remove LESS material rather than more -- they fall into
  // the ring's already-empty centre. Every other check here is blind to that.
  //
  // A hexagon's flat half-length at apothem r is r*tan(30), and the narrowest flat the
  // label touches is at its lower edge, band_mid - size/2. Derived, not measured, so it
  // tracks the band. At the shipped numbers this is 61.2mm -- and character count is not a
  // usable proxy for it: "NODE-01-RACK-A-XY" and "NODE-01-RACK-ABCD" are both 17 characters
  // and span 70.8mm and 74.1mm respectively.
  safe_width = 2 * (band_mid - dust_label_size / 2) * tan(30);

  // Published so the website can gate its label input on the REAL bound. Deriving it in
  // TypeScript instead would need sectionDust()'s 6.8 inner-wall literal, and a second copy
  // of that number is the drift layout-export.scad exists to prevent. Emitted before the
  // loop so the blank published render carries it too -- that render is the one the build
  // harvests, and a limit that only appeared for labelled parts would never be harvested at
  // all. scripts/generate-stl.sh reads it into manifest.labelLimit and FAILS without it,
  // because a missing limit ships an ungated input rather than a visible error.
  // font last: its value contains a space, so anything parsing this must take it as the
  // remainder of the line.
  echo(str("HEXRACK_DUST_LABEL",
           " safeWidthMm=", safe_width,
           " sizeMm=",      dust_label_size,
           " font=",        dust_label_font));

  for (label = [[dust_label_top, 1], [dust_label_bottom, -1]]) {
    if (label[0] != "") {
      // textmetrics is still an EXPERIMENTAL builtin -- it reads as undef, with a warning,
      // unless OpenSCAD ran with --enable=textmetrics. Guarded so a missing flag cannot
      // break every render, and only reached for a non-empty label, so the published parts
      // (which carry none) never trip the warning. scripts/test-dust-label.sh enables it.
      label_metrics = textmetrics(label[0], size = dust_label_size, font = dust_label_font);
      assert(is_undef(label_metrics) || label_metrics.size[0] <= safe_width,
             str("dust label \"", label[0], "\" is ",
                 is_undef(label_metrics) ? "?" : label_metrics.size[0],
                 "mm wide; the band's usable flat is ", safe_width,
                 "mm. Shorten it, or lower dust_label_size."));
      // rotate([90,0,0]) sends the extrusion down -Y and stands the glyphs up in XZ,
      // so starting at +dust_label_depth and running one depth plus EPS puts the cut
      // exactly between the front face and the engraving floor.
      translate([centre_xz[0], dust_label_depth - EPS, centre_xz[1] + label[1] * band_mid])
        rotate([90, 0, 0])
          linear_extrude(height = dust_label_depth + EPS)
            text(label[0], size = dust_label_size, font = dust_label_font,
                 halign = "center", valign = "center");
    }
  }
}

module sectionDust(depth=4 - OVERLAP) {
  body_height = hex_flat_to_flat(body_width-tolerance);
  size = body_width - tolerance;

  // Calculate inner hex dimensions for honeycomb_box_inner_twice
  inner_size = size - 4 * wall_thickness / cos(30);
  hex_flat_height = inner_size * cos(30);
  hex_center_z = size / 2;
  hex_top_z = hex_center_z + hex_flat_height / 2;
  hex_bottom_z = hex_center_z - hex_flat_height / 2;

  cut_amount = 0;  // How much to cut from top and bottom

  // The label is subtracted from the finished ring rather than from the outer profile
  // alone, so it cannot be re-filled by anything unioned on afterwards.
  difference() {
  union() {
    translate([0, 0, (-(body_width-tolerance) + body_height)/2 + tolerance/2]) {
      difference() {
        // Outer cutout shape
        honeycomb_box_inner((body_width-tolerance), depth, wall_thickness);

        // Inner cutout - with top/bottom trimmed
        translate([0, -1, 0])
        honeycomb_box_inner_twice((body_width-tolerance), wall_thickness, 6.8);

        glue_depth=0.32;
        translate([0, depth - glue_depth + EPS, 0])
        honeycomb_box_inner_twice((body_width-tolerance), glue_depth, 6.8 - 2);
      }
    }

    cube_width=30;
    cube_length=dust_clip_length;
    // Bottom
    translate([0, dust_clip_y, wall_thickness + tolerance/2])
    rotate([45, 0, 0])
    union() {
      translate([body_width/2 - cube_width/2, 0, 0])
      rotate([0, 90, 0])
      cube([cube_length, cube_length, cube_width]);
    }

    // Top
    translate([0, dust_clip_y, body_height - (wall_thickness - tolerance/2)])
    rotate([45, 0, 0])
    union() {
      translate([body_width/2 - cube_width/2, 0, 0])
      rotate([0, 90, 0])
      cube([cube_length, cube_length, cube_width]);
    }
  }

  // Same two hexagons the ring above is built from, and the same centring, so the
  // band the text sits in is the band that actually exists.
  dustLabelCutter(
    outer_p2p = size - 2 * wall_thickness / cos(30),
    inner_p2p = size - 4 * 6.8 / cos(30),
    centre_xz = [size / 2,
                 size / 2 + (-size + body_height) / 2 + tolerance / 2]);
  }
}

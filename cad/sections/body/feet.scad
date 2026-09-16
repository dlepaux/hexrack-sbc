include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/dovetails.scad>
use <../../lib/vent-patterns.scad>

// A foot is the "case below" a staggered unit: its top is that unit's bottom plane
// (Z = 0 here, in case coordinates) and it carries the same male "top" rail a real
// neighbour's back-top would, so it slides into the bottom groove from the back.
// The case above therefore needs the "bottom" groove -- website/lib/rack.ts adds it
// to every unit that gets a foot.
module sectionFeet() {
  assert(contains(["triangle", "triangle-closed", "x", "x-pads", "half-cell", "trunk"], feet_style),
         str("sectionFeet: unknown feet_style '", feet_style, "'"));

  if (feet_style == "trunk") feetTrunk();
  else if (feet_style == "x" || feet_style == "x-pads") feetX(pads = feet_style == "x-pads");
  else if (feet_style == "half-cell") feetHalfCell();
  else feetTriangle(closed = feet_style == "triangle-closed");
}

// The TPU pads the "x-pads" foot stands on. One part for both, placed in their pockets.
module sectionFeetPads() {
  body_height = hex_flat_to_flat(body_width);
  f = feet_pad_fit;

  for (y = feetPadPocketsY())
    translate([(body_width - feet_pad_size[0]) / 2 + f, y + f, -body_height / 2])
    cube([feet_pad_size[0] - 2 * f, feet_pad_size[1] - 2 * f,
          feet_pad_pocket + feet_pad_protrusion]);
}

// Near edge of each pocket along the case depth: one towards the front, one the back.
function feetPadPocketsY() =
  let (case_depth = face_depth + fan_depth + back_depth + back_face_thickness)
  [feet_pad_inset, case_depth - feet_pad_inset - feet_pad_size[1]];

// The rail back-top carries on its "top" face, dropped one case height so it lands on
// this case's bottom plane.
//
// Its span is set by the two ends of the foot's travel, not copied from back-top:
//   - front: back-bottom's groove starts 1mm in, and that closed 1mm is the stop the
//     rail slides home against. 0.1 short of it, as on back-top, keeps the foot flush
//     with the case front -- start it further back and the foot overshoots by the gap.
//   - back: exactly the case's back end, which is the foot's back end. The foot prints
//     standing on that end, so a flush rail gives a whole first layer; one that runs
//     past it prints its tip alone, proud of the bed face. back-face carries the groove
//     through its full thickness, so there is nothing for the rail to stop on there.
function feetRailStartY() = face_depth + fan_depth + 1 + 0.1;
function feetRailEndY() = face_depth + fan_depth + back_depth + back_face_thickness;

module feetRail() {
  body_height = hex_flat_to_flat(body_width);

  translate([0, 0, -body_height])
  dovetailIntercase("top", "male", body_height,
                    feetRailStartY(), feetRailEndY() - feetRailStartY());
}

module feetTriangle(closed) {
  body_height = hex_flat_to_flat(body_width);

  // The unit's bottom-left and bottom-right faces run from its side vertices to the
  // ends of its bottom flat; continued, they meet exactly body_height/2 lower. So the
  // triangle's apex is on the floor by construction, with no calibration.
  outline = [
    [body_width / 4, 0],
    [3 * body_width / 4, 0],
    [body_width / 2, -body_height / 2],
  ];

  // Open, it is a tube as thick as the case wall, so from the front it reads as one more
  // cell of the honeycomb. Closed, it is solid -- the slicer's walls and infill make it
  // hollow anyway, so this costs no plastic over capping the ends.
  feetProfile(outline, closed);
  feetRail();
}

// Two triangles tip to tip: flat on the case, flat on the floor, the case's bottom flat
// repeated on the floor. Hollow, the two walls that cross read as an X between two plates.
// With pads it stops short of the floor by what they stick out, and carries their pockets.
module feetX(pads) {
  body_height = hex_flat_to_flat(body_width);
  drop = body_height / 2 - (pads ? feet_pad_protrusion : 0);
  // Two walls wide, so the offset below closes the waist into solid material and the
  // cavities stay two separate triangles -- a narrower waist is a hinge, not a crossing.
  waist = 2 * wall_thickness;

  outline = [
    [body_width / 4, 0],
    [3 * body_width / 4, 0],
    [(body_width + waist) / 2, -drop / 2],
    [3 * body_width / 4, -drop],
    [body_width / 4, -drop],
    [(body_width - waist) / 2, -drop / 2],
  ];

  difference() {
    feetProfile(outline, closed = false);

    if (pads)
      for (y = feetPadPocketsY())
        translate([(body_width - feet_pad_size[0]) / 2, y, -drop - EPS])
        cube([feet_pad_size[0], feet_pad_size[1], feet_pad_pocket + EPS]);
  }
  feetRail();
}

// The upper half of the cell that is missing under a raised unit: it fills the gap flush
// with both lower neighbours, so the rack's outline closes into a complete honeycomb.
// Its slanted faces ARE the neighbours' faces, less feet_side_clearance to slide past them.
module feetHalfCell() {
  body_height = hex_flat_to_flat(body_width);
  drop = body_height / 2;
  // A 60-degree face moved in by the clearance along its normal moves this far in X.
  shift = feet_side_clearance / sin(60);
  outline = [
    [body_width / 4 + shift, 0],
    [3 * body_width / 4 - shift, 0],
    [body_width - shift, -drop],
    [shift, -drop],
  ];
  panel_t = face_panel_thickness();

  // The panel is flush with the FRONT, not recessed as the face's is: the foot prints
  // standing on this end, and a recessed perforated panel would be a bridge in mid-air.
  difference() {
    union() {
      feetProfile(outline, closed = false);
      translate([0, panel_t, 0]) rotate([90, 0, 0]) linear_extrude(panel_t) polygon(outline);
    }

    // The missing cell's own face pattern -- the same cutter, placed as that cell -- kept
    // inside the tube's opening so the walls are its rim and a gyroid cannot come apart.
    intersection() {
      translate([0, 0, -body_height]) ventPatternCutter(body_width, panel_t);
      translate([0, panel_t + EPS, 0]) rotate([90, 0, 0]) linear_extrude(panel_t + 2 * EPS)
        offset(delta = -wall_thickness) polygon(outline);
    }
  }
  feetRail();
}

// A foot's front-view outline run the full case depth. Printed standing on an end: every
// wall, the rail included, is then vertical.
module feetProfile(outline, closed) {
  case_depth = face_depth + fan_depth + back_depth + back_face_thickness;

  translate([0, case_depth, 0])
  rotate([90, 0, 0])
  linear_extrude(case_depth)
  difference() {
    polygon(outline);
    if (!closed) offset(delta = -wall_thickness) polygon(outline);
  }
}

module feetTrunk() {
  body_height = hex_flat_to_flat(body_width);

  // Calibration, not a tidy-uppable magic number: it is what lands the trunk on the floor
  // plane. A foot bridges the half-column offset between staggered units -- body-feet-trunk.stl
  // spans Z -64.948..+1.00 against a half case height of 64.952, so it drops the offset it
  // has to bridge to within 0.004mm. Derived from the printed geometry, not from theory;
  // change it only against a measured part.
  adjustement = 4.79;
  foot_height = body_height/2 - adjustement;
  extra = 10;

  support_width = 29.5 * 2.25;
  support_depth = 29.5 * 4;
  core_depth = support_depth * 0.63;

  // Elliptical core of the trunk. The mesh around it is irregular, the core is not, so
  // the rail is clipped to it: the trunk's cut top is far shorter than the rail, and the
  // overhanging ends would print in mid-air.
  //
  // That clipping also moves the rail's front end back to the core's, so the trunk sits
  // where the stop puts it: core front on the rail start. Placed anywhere further back,
  // it would slide forward that far before seating -- the model would not be the rack.
  support_center_y = feetRailStartY() + core_depth / 2;

  module core(h) {
    translate([body_width/2, support_center_y, -2 - foot_height])
    resize([support_width * 0.68, core_depth, h], auto=true)
    cylinder(h=foot_height, r=support_width/2.25, $fn=64);
  }

  difference() {
    union() {
      translate([body_width/2, support_center_y, -2 - foot_height])
      resize([support_width*1.5, support_depth * 1.25, foot_height + extra], auto=true)
      import("../../assets/TreeTrunk.stl", convexity=3);

      core(foot_height + extra);
    }

    translate([body_width/2 - support_width/2 - 25, support_center_y - support_depth/2 - 25, 0])
    cube([support_width + 50, support_depth + 50, 50]);
  }

  intersection() {
    feetRail();
    core(foot_height + extra);
  }
}

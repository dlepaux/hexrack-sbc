include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/dovetails.scad>

// A foot is the "case below" a staggered unit: its top is that unit's bottom plane
// (Z = 0 here, in case coordinates) and it carries the same male "top" rail a real
// neighbour's back-top would, so it slides into the bottom groove from the back.
// The case above therefore needs the "bottom" groove -- website/lib/rack.ts adds it
// to every unit that gets a foot.
module sectionFeet() {
  assert(feet_style == "trunk" || feet_style == "triangle" || feet_style == "triangle-closed",
         str("sectionFeet: unknown feet_style '", feet_style, "'"));

  if (feet_style == "trunk") feetTrunk();
  else feetTriangle(closed = feet_style == "triangle-closed");
}

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
  case_depth = face_depth + fan_depth + back_depth + back_face_thickness;

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
  // hollow anyway, so this costs no plastic over capping the ends. Printed standing on an
  // end: every wall, the rail included, is then vertical.
  translate([0, case_depth, 0])
  rotate([90, 0, 0])
  linear_extrude(case_depth)
  difference() {
    polygon(outline);
    if (!closed) offset(delta = -wall_thickness) polygon(outline);
  }

  feetRail();
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

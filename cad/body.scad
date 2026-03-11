include <config.scad>
use <lib/shapes.scad>
use <components/fan.scad>
use <components/drawers.scad>

use <SBC_Model_Framework/sbc_models.scad>
include <SBC_Model_Framework/sbc_models.cfg>

use <lib/sbc-helpers.scad>
use <lib/pironman-base.scad>

use <sections/body/face.scad>
use <sections/body/fan.scad>
use <sections/body/back.scad>
use <sections/body/back-top.scad>
use <sections/body/back-face.scad>
use <sections/body/back-bottom.scad>
use <sections/body/dust.scad>
use <sections/body/feet.scad>
use <sections/body/top-supports.scad>

if (body_part == "assembly") {
  translate([0, 0, 0])
  sectionFace();

  translate([0, 3 + OVERLAP, 0])
  sectionDust();

  translate([0, face_depth + bodyAssembly_space, 0])
  sectionFan();

  translate([0, face_depth + fan_depth + bodyAssembly_space*2, 0])
  sectionBack();
}

if (body_part == "face_dust") {
  translate([0, 0, 0])
  sectionFace();

  translate([0, 3 + OVERLAP, 0])
  sectionDust();
}
if (body_part == "top-supports") {
  translate([0, 0, 0])
  sectionTopSupports();
}
if (body_part == "dust") {
  translate([0, 0, 0])
  sectionDust();
}
if (body_part == "fan") {
  translate([0, 0, 0])
  sectionFan();
}
if (body_part == "face") {
  translate([0, 0, 0])
  sectionFace();
}
if (body_part == "feet") {
  translate([0, 0, 0])
  sectionFeet();
}
if (body_part == "back") {
  translate([0, 0, 0])
  sectionBack();
}
if (body_part == "back-top") {
  translate([0, 0, 0])
  sectionBackTop();
}
if (body_part == "back-face") {
  translate([0, 0, 0])
  sectionBackFace();
}
if (body_part == "back-bottom") {
  translate([0, 0, 0])
  sectionBackBottom();
}

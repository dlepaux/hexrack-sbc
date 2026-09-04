include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/fan.scad>
use <../../components/drawers.scad>
use <../../components/mounting-holes.scad>

use <../../SBC_Model_Framework/sbc_models.scad>
include <../../SBC_Model_Framework/sbc_models.cfg>

use <../../lib/sbc-helpers.scad>
use <../../lib/pironman-base.scad>

use <back-top.scad>
use <back-bottom.scad>
use <back-face.scad>
use <back-fan.scad>
use <top-supports.scad>

module sectionBack() {
  translate([0, bodyAssembly_space/4 + bodyAssembly_back_space/4, -bodyAssembly_space/4 - bodyAssembly_back_space/4])
  sectionBackBottom();

  translate([0, bodyAssembly_space/4 + bodyAssembly_back_space/4, bodyAssembly_space/4 + bodyAssembly_back_space/4])
  sectionBackTop();

  // back-fan sits between the back halves and the back face on the boards that have a
  // rear pull fan; on the others the back face follows the back directly, so the offset
  // has to be conditional rather than a constant.
  if (rear_fan_enabled())
    translate([0, bodyAssembly_space/2 + back_depth, 0])
    sectionBackFan();

  translate([0, bodyAssembly_space/2 + back_depth
                + (rear_fan_enabled() ? back_fan_depth + bodyAssembly_space/2 : 0), 0])
  sectionBackFace();

  translate([0, bodyAssembly_space/4, bodyAssembly_space/6])
  sectionTopSupports();
}

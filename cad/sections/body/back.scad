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
use <top-supports.scad>

module sectionBack() {
  translate([0, bodyAssembly_space/4, -bodyAssembly_space/4])
  sectionBackBottom();

  translate([0, bodyAssembly_space/4, bodyAssembly_space/4])
  sectionBackTop();

  translate([0, bodyAssembly_space/2 + back_depth, 0])
  sectionBackFace();

  translate([0, bodyAssembly_space/4, bodyAssembly_space/6])
  sectionTopSupports();
}

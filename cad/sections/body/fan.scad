include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/fan.scad>
use <../../components/drawers.scad>
use <../../components/mounting-holes.scad>

use <../../SBC_Model_Framework/sbc_models.scad>
include <../../SBC_Model_Framework/sbc_models.cfg>

use <../../lib/sbc-helpers.scad>
use <../../lib/pironman-base.scad>

module sectionFan() {
  body_height = hex_flat_to_flat(body_width);

  difference() {
    union() {
      translate([0, 0, (-body_width + body_height)/2])
      honeycomb_shell(body_width, fan_depth, 2.6);

      // Male
      translate([0, -3 + EPS, (-body_width + body_height)/2])
      honeycomb_shell(body_width, 3, 1.2);

      translate([0, fan_depth - 3, 0])
      intersection() {
        translate([0, 0, (-body_width + body_height)/2])
        honeycomb_box(body_width, 3, 0);

        translate([0, 0, (-body_width + body_height)/2])
        roundedPanel(
          body_width,
          wall_thickness,
          corner_radius,
          0,
          center_hole=fan_size_mode
        );
      }
    }

    // Female
    extra_female = EPS;
    translate([-extra_female/2, fan_depth - 3 + extra_female/2, (-body_width + body_height)/2 - extra_female/2])
    honeycomb_shell(body_width + extra_female, 3, 1.3);

    translate([0, -OVERLAP*5, 0])
    frontfaceMountingHolesFront(type="through", body_height=body_height);

    translate([0, 0, (-body_width + body_height)/2])
    fanMountingHoles();
  }

  if (show_fan) {
    %translate([body_width/2, fan_depth, body_height/2])
    fanVisualization92();
  }
}

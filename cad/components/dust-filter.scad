include <../config.scad>

module dustFilterVisualization() {
  // Square dust filter with rounded corners positioned in front of the dust filter part
  translate([
    body_size / 2,
    dust_filter_thickness + dust_filter_y_offset - EPS,
    body_size / 2
  ])
  color("black", 0.5)
  rotate([90, 0, 0])
  linear_extrude(height=dust_filter_thickness, center=false)
  difference() {
    // Outer square frame with rounded corners
    offset(r=inner_corner_radius, $fn=40)
    square([dust_filter_outer_diameter - 2*inner_corner_radius, dust_filter_outer_diameter - 2*inner_corner_radius], center=true);
    // Inner square cutout with rounded corners
    offset(r=inner_corner_radius, $fn=40)
    square([dust_filter_inner_diameter - 2*inner_corner_radius, dust_filter_inner_diameter - 2*inner_corner_radius], center=true);
  }
}

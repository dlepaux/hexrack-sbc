include <../config.scad>

module fanVisualization92() {
  depth = 25;

  #rotate([90, 0, -180])
  translate([0, 0, -depth + wall_thickness + 3])
  color("SaddleBrown", 1)
  import("../assets/noctua-92.stl", center=true);
}



/**
 * Module: M4 Nut Trap
 * Description: Creates a hexagonal nut trap for M4 screws
 */
module m3_nut_trap(height=30) {
  // M3 nut dimensions
  nut_width = 5.46 + 0.4;      // width across flats (mm)
  nut_height = height;   // thickness (mm)
  
  // Calculate diameter to vertices for hexagon
  // diameter = width_across_flats / cos(30)
  hex_diameter = nut_width / cos(30);
  
  // Create hexagonal shape
  cylinder(h=nut_height, d=hex_diameter, $fn=6, center=true);
}

/**
 * Module: M4 Nut Trap
 * Description: Creates a hexagonal nut trap for M4 screws
 */
module m4_nut_trap(height=30) {
  // M4 nut dimensions
  nut_width = 6.8 + 0.4;      // width across flats (mm)
  nut_height = height;   // thickness (mm)
  
  // Calculate diameter to vertices for hexagon
  // diameter = width_across_flats / cos(30)
  hex_diameter = nut_width / cos(30);
  
  // Create hexagonal shape
  cylinder(h=nut_height, d=hex_diameter, $fn=6, center=true);
}
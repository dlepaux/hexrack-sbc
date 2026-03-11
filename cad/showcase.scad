// ============================================================================
// HEXRACK SBC - SHOWCASE ASSEMBLY
// ============================================================================
// Renders the 3-unit honeycomb stack matching the actual setup:
//   - Bottom-left:  Raspberry Pi 5 + Pironman #1
//   - Top-left:     Raspberry Pi 5 + Pironman #2 (stacked on #1)
//   - Right (offset): Rock 5B+ with feet, nestled between the two Pi5 units
//
// Requires pre-generated assembly STLs in the same output directory.
// Usage: openscad -D 'stl_path="path/to/stls"' showcase.scad
// ============================================================================

// Path to pre-generated STL files (override with -D from generate-stl.sh)
// Default assumes running from project root: ../public/stl relative to cad/
stl_path = "../public/stl";

// Hex dimensions (must match config.scad)
body_width = 150;
body_height = body_width * cos(30); // flat-to-flat ≈ 129.9mm

// Honeycomb offset: adjacent column center-to-center X distance
hex_x_offset = body_width * 3 / 4;

// PI5 #1 - Bottom left
color("DimGray")
  import(str(stl_path, "/body-assembly-rpi5_pironman.stl"));

// PI5 #2 - Top left (stacked on #1)
color("DimGray")
  translate([0, 0, body_height])
    import(str(stl_path, "/body-assembly-rpi5_pironman.stl"));

// Rock 5B+ - Right, honeycomb offset (nestled between the two Pi5 units)
color("SlateGray")
  translate([hex_x_offset, 0, body_height / 2])
    import(str(stl_path, "/body-assembly-rock5b+.stl"));

// Feet - Under Rock 5B+
color("SaddleBrown")
  translate([hex_x_offset, 0, body_height / 2])
    import(str(stl_path, "/body-feet.stl"));

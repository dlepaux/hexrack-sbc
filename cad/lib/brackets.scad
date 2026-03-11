// ============================================================================
// CORNER BRACKETS - Structural Reinforcement
// ============================================================================
// Triangular corner brackets for drawer structural support.
// Use: use <lib/brackets.scad>
// ============================================================================

include <../config.scad>

// ============================================================================
// MODULES
// ============================================================================

// Low-profile triangular bracket for structural reinforcement
// Has pass-through hole for body mounting screw
// Parameters:
//   depth        - Drawer depth (triangle leg along Y)
//   height       - Bracket height along X (default: corner_bracket_height - panel_thickness)
//   width        - Extrusion width (default: corner_bracket_width)
//   screw_d      - Screw hole diameter (default: get_screw_spec("M3-16", "pilot_hole_diameter"))
//   screw_offset - Distance from corner to screw (default: corner_bracket_screw_offset)
module corner_bracket(
  depth,
  height = undef,
  width = undef,
  screw_d = undef,
  screw_offset = undef
) {
  _height = height != undef ? height : corner_bracket_height - panel_thickness;
  _width = width != undef ? width : corner_bracket_width;
  _screw_d = screw_d != undef ? screw_d : get_screw_spec("M3-16", "pilot_hole_diameter");
  _screw_offset = screw_offset != undef ? screw_offset : corner_bracket_screw_offset;

  difference() {
    color("lightgray")
      linear_extrude(height=_width)
        polygon(
          [
            [0, 0], // Origin
            [_height, 0], // Along X
            [0, -depth + panel_thickness], // Along Y (negative)
          ]
        );

    // Pass-through hole for body mounting screw
    translate([_screw_offset, -_screw_offset, -EPS])
      cylinder(d=_screw_d, h=_width + 2 * EPS, $fn=30);
  }
}

// Tall triangular bracket (full panel height for better support)
// Offset inward to avoid rail collision
// Note: Front panel holes are created by front_panel_mounting_mask() in the assembly
// Parameters:
//   depth           - Drawer depth (triangle leg along Y)
//   height          - Panel height (triangle leg along X)
//   width           - Extrusion width (default: corner_bracket_width)
//   screw_d         - Body mounting screw diameter
//   screw_offset    - Distance from corner to body screw
module corner_bracket_tall(
  depth,
  height,
  width = undef,
  screw_d = undef,
  screw_offset = undef
) {
  _width = width != undef ? width : corner_bracket_width;
  _screw_d = screw_d != undef ? screw_d : get_screw_spec("M3-16", "pilot_hole_diameter");
  _screw_offset = screw_offset != undef ? screw_offset : corner_bracket_screw_offset;

  difference() {
    color("lightgray")
      linear_extrude(height=_width)
        polygon(
          [
            [0, 0], // Origin
            [height - panel_thickness, 0], // Along X (full panel height)
            [0, -depth + panel_thickness], // Along Y (drawer depth)
          ]
        );

    // Body mounting hole - screw from body exterior
    translate([_screw_offset, -_screw_offset, -EPS])
      cylinder(d=_screw_d, h=_width + 2 * EPS, $fn=30);
  }
}

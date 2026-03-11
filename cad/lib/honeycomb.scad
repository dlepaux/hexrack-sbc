// ============================================================================
// HONEYCOMB PATTERN - Ventilation Cutouts
// ============================================================================
// Generates honeycomb patterns for ventilation panels.
// Use: use <lib/honeycomb.scad>
// ============================================================================

// ============================================================================
// FUNCTIONS
// ============================================================================

// Calculate honeycomb dimensions that will be rendered
// Returns: [actual_width, actual_height, cols_even, cols_odd, rows]
//   cols_even = number of hexagons in even rows (0, 2, 4...)
//   cols_odd = number of hexagons in odd rows (1, 3, 5...)
function honeycombDimensions(available_width, available_height, hex_size) =
  let (
    hex_width = hex_size * sqrt(2),
    hex_height = hex_size * 0.55,
    h_spacing = hex_width,
    v_spacing = hex_height * 0.75,

    // Calculate how many hexagons fit
    cols_fit = floor(available_width / h_spacing),
    rows_fit = floor(available_height / v_spacing),

    // Force ODD number for even rows (visual symmetry)
    cols_even = cols_fit < 1 ? 1 : (cols_fit % 2 == 0 ? cols_fit - 1 : cols_fit),

    // Odd rows have one less hexagon (nestle between even rows)
    cols_odd = cols_even - 1,

    // Rows can be any number
    rows = rows_fit < 1 ? 1 : rows_fit,

    // Calculate actual pattern dimensions
    actual_width = (cols_even - 1) * h_spacing,
    actual_height = rows * v_spacing
  ) [actual_width, actual_height, cols_even, cols_odd, rows];

// ============================================================================
// MODULES
// ============================================================================

// Single hexagon (6-sided circle)
module hexagon(size) {
  circle(d=size, $fn=6);
}

// Generate honeycomb pattern from origin [0,0]
// NO internal centering - caller handles all positioning
// Parameters:
//   cols_even      - Hexagons in even rows (0, 2, 4...) - should be ODD for symmetry
//   cols_odd       - Hexagons in odd rows (1, 3, 5...) - typically cols_even - 1
//   rows           - Number of rows
//   hex_size       - Hexagon diameter
//   wall_thickness - Wall between hexagons (subtracted from hex_size)
module honeycomb_pattern(cols_even, cols_odd, rows, hex_size, wall_thickness) {
  hex_width = hex_size * sqrt(2);
  hex_height = hex_size * 0.55;

  h_spacing = hex_width;
  v_spacing = hex_height * 0.75;

  // Generate hexagons from origin
  for (row = [0:rows - 1]) {
    // Even rows: full columns, start at 0
    // Odd rows: one less column, offset by half spacing
    num_cols = (row % 2 == 0) ? cols_even : cols_odd;
    x_start = (row % 2 == 0) ? 0 : h_spacing / 2;

    for (col = [0:num_cols - 1]) {
      translate([x_start + col * h_spacing, row * v_spacing, 0])
        hexagon(hex_size - wall_thickness);
    }
  }
}

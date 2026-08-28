// ============================================================================
// HEXRACK SBC - CONFIGURATION
// ============================================================================
// All parameters in one place for easy customization.
// Include this file in your .scad files: include <config.scad>
// ============================================================================

// ============================================================================
// GENERAL
// ============================================================================
EPS = 0.01;                // Small value for CSG operations (prevents z-fighting)
OVERLAP = 0.1;             // Overlap margin for panel connections
tolerance = 0.4;           // General fit tolerance

// Include screw specifications and API from lib/screws.scad
include <lib/screws.scad>

// ============================================================================
// BODY DIMENSIONS
// ============================================================================
body_width = 150;          // Width and height (square profile)
body_depth = 200;          // Depth (adjustable for final assembly)
// Back
back_depth = 115;
// Fan
fan_depth = 31; // Noctua 92mm
face_depth = 6 + tolerance; // Noctua 92mm
wall_thickness = 5;        // Wall thickness
corner_radius = 10;        // Radius for rounded corners (exterior)
inner_corner_radius = 6;   // Radius for rounded corners (interior)

// ============================================================================
// FAN SPECIFICATIONS (Noctua NF-A9 PWM 92mm)
// ============================================================================
fan_size = 92;            // Fan width and height (92x92mm)
fan_thickness = 30;        // Fan depth without anti-vibration pads
fan_with_pads = 32;        // Fan depth with anti-vibration pads
fan_extra_space = 1;       // Additional clearance for fan
fan_mount_hole_diameter = 4.3;  // Mounting hole diameter (4mm + tolerance)

// Fan mounting hole patterns (center to center distances)
fan_mount_71 = 71.5;  // 110 x 180 mm pattern (asymmetric)

pironman_offset_for_nvme = 7;

// ============================================================================
// PRESETS
// ============================================================================
// Preset format: [board_model, height, x_offset, y_offset, z_offset]
//   - board_model: SBC model name (e.g., "rock5b+", "rpi5_pironman")
//   - height: Drawer height in mm
//   - x_offset: X adjustment from auto-centered position
//   - y_offset: Y adjustment from auto-centered position
//   - z_offset: Z adjustment to normalize board z position
//
//   - standoff_z_offset: Physical standoff height (separate hardware, in mm)
//
//   - drawer_front_board_x_offset: X offset for front board position
//   - drawer_front_board_y_offset: Y offset for front board position
//   - drawer_front_board_mask_x_offset: X offset for front board mask position
//   - drawer_front_board_mask_y_offset: Y offset for front board mask position
//
//   - honeycomb_padding: Padding from left/right edges
//   - honeycomb_padding_top: Honeycomb padding from top edge
//   - honeycomb_padding_bottom: Honeycomb padding from bottom edge
//   - honeycomb_pattern_z_offset: Honeycomb vertical offset adjustment
//
// Board final Z position calculated as:
//   board_z = z_offset + panel_thickness + standoff_z_offset
//
// Note: Effective width/depth are calculated from natural dimensions + rotation
//       Edit get_natural_board_width/depth() to change board dimensions
//       Use setup.scad to visually configure offset values

// Rock5b+ Case Standoff: 7.43mm (dual middle support)
preset_rock5b = [
  "rock5b+", 0, 0, -0.7, 0,
  49,
  0, 0.75, 0, 1,
  54, 20, 8, 0,
];

// Pironman Case Standoff: 5mm
preset_pironman = [
  "rpi5_pironman", 0, 40.5, -2.5,
  28,
  -1.50, 0, -1, 0,
  40, 20, 0, 0,
];

// Empty (short: 84, large: )
preset_empty = [
  undef, 84, 0, 0, 0,
  0,
  0, 0, 0, 0,
  250, 10, 2, 6.8,
];

// Helper functions to extract preset values
function preset_board_model(preset) = preset == undef ? false : preset[0];
function preset_height(preset) = preset == undef ? false : preset[1];
function preset_x_offset(preset) = preset == undef ? false : preset[2];
function preset_y_offset(preset) = preset == undef ? false : preset[3];
function preset_z_offset(preset) = preset == undef ? false : preset[4];
function preset_standoff_z_offset(preset) = preset == undef ? false : preset[5];
function preset_drawer_front_board_x_offset(preset) = preset == undef ? false : preset[6];
function preset_drawer_front_board_y_offset(preset) = preset == undef ? false : preset[7];
function preset_drawer_front_board_mask_x_offset(preset) = preset == undef ? false : preset[8];
function preset_drawer_front_board_mask_y_offset(preset) = preset == undef ? false : preset[9];
function preset_honeycomb_padding(preset) = preset == undef ? false : preset[10];
function preset_honeycomb_padding_top(preset) = preset == undef ? false : preset[11];
function preset_honeycomb_padding_bottom(preset) = preset == undef ? false : preset[12];
function preset_honeycomb_pattern_z_offset(preset) = preset == undef ? false : preset[13];

// Calculate effective dimensions from natural dimensions + rotation
function preset_effective_width(model) =
    let(rotation = get_board_rotation(model))
    (abs(rotation[2]) == 90 || abs(rotation[2]) == 270) ?
        get_natural_board_depth(model) :
        get_natural_board_width(model);

function preset_effective_depth(model) =
    let(rotation = get_board_rotation(model))
    (abs(rotation[2]) == 90 || abs(rotation[2]) == 270) ?
        get_natural_board_width(model) :
        get_natural_board_depth(model);

// ============================================================================
// BOARD POSITIONING (Defaults)
// ============================================================================
// Exclusion zone for honeycomb (board-specific)
// Format: [z_offset, height, width]
//   - z_offset: Vertical offset from board_z position (can be negative)
//   - x_offset: Horizontal offset from board_z position (can be negative)
//   - height: Height of the exclusion zone in mm
//   - width: Width of the exclusion zone in mm
// Note: Width is per single board; drawer.scad calculates total for multiple boards
function get_exclusion_zone(model) =
    model == "rock5b+" ? [-1.5, 0, 22, 100] :
    model == "rpi5_pironman" ? [-0.5, 0, 22.5, 98] :
    [0, 0, 0];

// Board rotation (board-specific)
// Format: [x, y, z] rotation in degrees
function get_board_rotation(model) =
    model == "rock5b+" ? [0, 0, 0] :
    model == "rpi5_pironman" ? [0, 0, -90] :
    [0, 0, 0];

// Natural board dimensions (before rotation)
// Used by setup.scad for visualization
function get_natural_board_width(model) =
    model == "rock5b+" ? 100 :
    model == "rpi5_pironman" ? 85 :
    100;  // Default width

function get_natural_board_depth(model) =
    model == "rock5b+" ? 75 :
    model == "rpi5_pironman" ? 95.83 :
    85;  // Default depth

// ============================================================================
// HONEYCOMB VENTILATION
// ============================================================================
honeycomb_size = 10;               // Size of hexagon cells
honeycomb_wall_thickness = 1.5;    // Thickness of honeycomb walls

// ============================================================================
// TEXTOVER (Labels above SBCs)
// ============================================================================
textover_font_primary = "OldLondon:style=Regular";  // Font for text labels
textover_font_secondary = "PTMono:style=Bold";  // Font for text labels
textover_font_size_primary = 10;            // Text size in mm
textover_font_size_secondary = 3;            // Text size in mm
textover_line_spacing = 1.5;       // Space between lines in mm
textover_depth = 1;              // Engraving depth in mm
textover_z_offset = 3;             // Vertical offset from top of panel

// ============================================================================
// SBC MOUNTING SUPPORTS
// ============================================================================
mounting_hole_clearance = 0.3;         // Extra clearance for easier mounting
support_pillar_inset = 2.75;            // Wall thickness around screw hole
support_inner_diameter_modifier = 0.5; // Multiplier to reduce inner hole
support_base_diameter_ratio = 3.0;     // Bottom/top diameter ratio
support_taper_power = 0.6;             // Taper curve strength
support_layers = 20;                   // Layers for smooth taper

// ============================================================================
// Dovetails
// ============================================================================
dovetail_rail_height = 2.5;
dovetail_rail_base_width = 3;
dovetail_rail_mouting_z = 3;
dovetail_rail_penetration = 1.5;
dovetail_stop_distance = 10;
dovetail_clearance = 0.15;
dovetail_offset_x=3.5;
dovetail_rail_base_width_intercase=10;

// ============================================================================
// Pads
// ============================================================================
pad_total_width=16;
pad_length=16;
pad_x_offset=16;

// ============================================================================
// RENDER PARTS (File-based rendering)
// ============================================================================
// Each file renders its own content. Open the file you want to print/preview:
//   main.scad   → Full assembly preview
//   body.scad   → Body parts for printing
//   drawer.scad → Drawer parts for printing
//
// body_part: Which body part to render in body.scad
//   "assembly"        - Full body assembly (preview)
//   "dust"       - Decorative front grille (for printing)
//   "face"       - Decorative front grille (for printing)
//   "fan"           - Front section (for printing)
//   "feet"            - Back section with rails (for printing)
//   "back"            - Back section with rails (for printing)
//   "back-top"            - Back section with rails (for printing)
//   "back-face"            - Back section with rails (for printing)
//   "back-bottom"            - Back section with rails (for printing)
//   "top-supports"            - Back section with rails (for printing)
body_part = "assembly";
bodyAssembly_space = 50;

back_mounting_brackets_bevel_size = 10;
back_mounting_brackets_width=10;
back_mounting_brackets_back_width=back_mounting_brackets_width*3;
back_mounting_brackets_height=10;
back_mounting_brackets_depth=25;

back_face_thickness=3;
face_thickness = 2;

// ============================================================================
// WIFI ANTENNAS (back panel, symmetric around port cutout)
// ============================================================================
enable_wifi_antennas = false;            // Toggle antenna holes in back panel
antenna_thread_diameter = 6.2;          // Male thread Ø (major)
antenna_clearance = 0.4;                // Print fit tolerance (hole + nut trap)
antenna_nut_flats = 8;                  // Nut width across flats (8mm AF)
antenna_nut_thickness = 2;              // Nut depth (sits in trap on inside face)
antenna_thread_length = 10;             // Male post length (full thread)

// Placement — symmetric around body_width/2
antenna_x_spread = 120;                 // Distance between the two holes (mm)

// Reinforcement pad — solid disc around each hole, fills voronoi cutouts
// so the panel has continuous material to grip the threaded post.
antenna_pad_diameter = 18;              // Solid pad Ø around each antenna hole

// Visualization (preview-only, not part of printed geometry)
show_antennas = true;                   // Render mounting post + nut for debug

// body_front_face_style: Which drawer style to use for front face
//   "fractal"           - Fractal pattern (default)
//   "pa602"             - PA602 pattern (alternative)
//   "louvered"          - Louvered pattern (alternative)
//   "warhammer"         - Warhammer pattern (alternative)
body_front_face_style = "fractal";

// Drawer board
//   "rpi5_pironman" - Pironman (Raspberry PI 5)
//   "rock5b+"            - Rock5b+
//   "test"               - Rock5b+
//   "empty"              - No board
// drawer_board = "rock5b+";
drawer_board = "rock5b+";

drawer_preset =
  drawer_board == "rock5b+" ? preset_rock5b
  : drawer_board == "rpi5_pironman" ? preset_pironman
  : preset_empty; // Default fallback

// ============================================================================
// DEBUG / VISUALIZATION TOGGLES
// ============================================================================
add_corner_brackets = true;              // Triangular structural brackets
add_honeycomb = true;                    // Honeycomb ventilation pattern
add_mounting_supports = true;            // Cylindrical support pillars
show_pads = true;                   // Show middle support
show_snap_fits = true;                   // Show middle support
show_sbc = true;                         // Show SBC model (transparent)
show_fan = false;                        // Show fan model (transparent)
fan_size_mode = 92;                        // Show fan model (transparent)
show_drawers = true;                    // Show drawers in body (transparent)
show_textover = true;                    // Show textover on front drawer's panel
show_sides_support=true;

// ============================================================================
// FRONT CIRCLE (face panel)
// ============================================================================
// A solid band traced across the voronoi panel at the fan bore diameter, so the
// front of the case reads as a circle inside the hexagon and lines up with the
// fan behind it. It interrupts the pattern rather than opening it, so the panel
// keeps its ventilation area -- unlike the fan section's web, which is a true bore.
enable_front_circle = true;             // Toggle the band on the face panel
front_circle_diameter = fan_size_mode;  // Band centreline Ø — tracks the fan bore
front_circle_band = 3;                  // Radial width of the band

// Dovetail Intercases
//   "top"
//   "top-right"
//   "top-left"
//   "bottom"
//   "bottom-right"
//   "bottom-left"
dovetail_intercase = [
  "top",
  "top-right",
  "top-left",
  "bottom",
  "bottom-right",
  "bottom-left"
];
// list = [2, 3, 1];
// isin = len(search(1, list)) > 0 ? 100 : 0;
// echo(isin);

function contains(arr, val) =
    len([for (i = arr) if (i == val) i]) > 0;

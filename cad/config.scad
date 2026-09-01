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
fan_mount_82_5 = 82.5;     // 92mm fan square pattern (center to center)
fan_screw = "M5-Noctua";   // Screw spec the fan mounting holes are cut with

// Half-pitch of the fan screw square: panel center to a hole, per axis.
// The cable notches in the fan web are sized off this, so the two must not be
// allowed to drift apart. Returns 0 for a fan size with no known pattern --
// callers assert on that rather than silently stacking holes at the center.
function fan_screw_offset(mode) =
    mode == 92 ? fan_mount_82_5 / 2 :
    mode == 80 ? fan_mount_71 / 2 :
    0;

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
//   - support_mandatory_standoff_height: Mandatory standoff height for supports, 0, 5, 10, 15 or 20
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
  10,
];

// Pironman Case Standoff: 5mm
preset_pironman = [
  "rpi5_pironman", 0, 40.5, -2.5, 0,
  28,
  -1.50, 0, -1, 0,
  40, 20, 0, 0,
  5,
];

// Empty (short: 84, large: )
preset_empty = [
  undef, 84, 0, 0, 0,
  0,
  0, 0, 0, 0,
  250, 10, 2, 6.8,
  0,
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
function preset_support_mandatory_standoff_height(preset) = preset == undef ? false : preset[14];

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
mounting_hole_clearance = 0.3;          // Extra clearance for easier mounting
support_pillar_inset = 2.75;            // Wall thickness around screw hole
support_inner_diameter_modifier = 0.5;  // Multiplier to reduce inner hole
support_base_diameter_ratio = 3.0;      // Bottom/top diameter ratio
support_taper_power = 0.6;              // Taper curve strength
support_layers = 20;                    // Layers for smooth taper

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
// Canoe
// ============================================================================
// Tolerance for treating two X values as "the same column"
canoe_group_tol   = 0.5;
// Extra width beyond the insert boss diameter (0 = exactly boss width)
canoe_wall        = 0.0;
// Overhang beyond the outermost holes (nose / tail)
canoe_nose        = 4.0;
// Lens bulge factor: 1.0 = circular arc, lower = flatter sides
canoe_bulge       = 0.75;
// Fillet radius where the canoe meets the floor
canoe_base_fillet = 1.5;

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
//   "assembly"     - Full body assembly (preview)
//   "dust"         - Decorative front grille (for printing)
//   "face"         - Decorative front grille (for printing)
//   "fan"          - Front section (for printing)
//   "feet"         - Back section with rails (for printing)
//   "back"         - Back section with rails (for printing)
//   "back-top"     - Back section with rails (for printing)
//   "back-face"    - Back section with rails (for printing)
//   "back-bottom"  - Back section with rails (for printing)
//   "top-supports" - Back section with rails (for printing)
body_part = "back";
bodyAssembly_space = 0;

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
show_fan = true;                        // Show fan model (transparent)
fan_size_mode = 92;                        // Show fan model (transparent)
show_drawers = true;                    // Show drawers in body (transparent)
show_textover = true;                    // Show textover on front drawer's panel
show_sides_support=true;

// ============================================================================
// FACE VENT PATTERN
// ============================================================================
// The decorative perforation cut into the face panel, in front of the fan.
// Every mode produces holes only, so switching one never moves the panel
// outline, the mounting bosses, or the front circle.
//
//   "voronoi"   - Organic cells imported from assets/voronoi_svg.svg (default)
//   "gyroid"    - Continuous open channels. A true gyroid cross-section, so the
//                 slots never close into cells and the panel reads as one flow.
//   "triangles" - Rounded equilateral lattice
//   "grid"      - Staggered horizontal slots (cyberpunk)
face_vent_patterns = ["voronoi", "gyroid", "triangles", "grid"];
face_vent_pattern = "triangles";

// Solid rim kept inside the hexagon edge, measured at the flats. Load-bearing,
// not cosmetic: a gyroid strand runs the full width of the panel, so with
// nothing tying the two halves together it saws the face into separate bodies
// the moment enable_front_circle stops filling the ring outside the fan bore.
face_vent_margin = 3;

// -- gyroid ------------------------------------------------------------------
face_vent_gyroid_period = 8;     // mm spanned by one full lattice cell
face_vent_gyroid_slot = 2;      // Slot width, perpendicular to the strand
// Which slice of the gyroid sits at the panel's mid-depth. It is not a free
// parameter: the strands are solved in closed form, and that solution exists at
// every x only while |sin(phase)| <= sqrt(1/2). The pattern sweeps
// face_thickness * 360 / period degrees between the panel's two faces, so the
// usable band is 45 degrees minus half that sweep. The library asserts on it.
face_vent_gyroid_phase = 0;
face_vent_gyroid_samples = 36;    // Polygon samples per cell along a strand
// Slices stacked through the panel depth. Each one is a prism, so this sets the
// staircase on the sheared slot walls -- keep the step at or under a print layer.
face_vent_gyroid_layers = 14;

// -- triangles ---------------------------------------------------------------
face_vent_triangle_cell = 14;     // Lattice edge length
face_vent_triangle_wall = 1.6;      // Web left between neighbouring holes
face_vent_triangle_radius = 1.2;  // Corner rounding on each hole
// Fraction of a cell that alternate rows shift by. 0.5 nests each row into the
// gaps of the one below and is also what makes the lattice mirror onto itself
// about the panel's midline -- the reflection that maps an up triangle onto a
// down one flips the row parity, so it needs that half-cell offset to land on
// anything. At 0 you get the strict lattice, evenly spread but not symmetric.
face_vent_triangle_stagger = 0.5;

// -- grid --------------------------------------------------------------------
face_vent_grid_slot = 4;          // Slot height
face_vent_grid_gap = 2;           // Web between rows
face_vent_grid_segment = 18;      // Slot length
face_vent_grid_spine = 3;         // Web between slots within a row
face_vent_grid_stagger = 0;       // Fraction of a column pitch alternate rows shift by
                                  // (0 = aligned grid, 0.5 = brick bond)

// ============================================================================
// FRONT CIRCLE (face panel)
// ============================================================================
// A solid band traced across the voronoi panel at the fan bore diameter, so the
// front of the case reads as a circle inside the hexagon and lines up with the
// fan behind it. It interrupts the pattern rather than opening it, so the panel
// keeps its ventilation area -- unlike the fan section's web, which is a true bore.
enable_front_circle = false;             // Toggle the band on the face panel
front_circle_diameter = fan_size_mode;  // Band centreline Ø — tracks the fan bore
front_circle_band = 3;                  // Radial width of the band

// ============================================================================
// FAN CABLE NOTCHES (fan section web)
// ============================================================================
// The fan drops into the web's bore and lands on its four frame corners, so its
// cable has no path through to the case interior. These notches bite into the
// bore edge so it has one.
//
// The four sit at 90 degree spacing, which is the load-bearing invariant: the fan
// can be fitted in any of its four rotations and its one cable corner always meets
// an identically placed opening. They are NOT on the corner diagonals, because the
// cable does not leave the frame at the corner -- it runs out along a strut and
// pierces the frame rail. Measured on assets/noctua-92.stl that exit sits 14.85
// degrees past the diagonal, at r = 53.2 from the fan centre; on the diagonal the
// cable misses the notch entirely.
//
// The offset costs the four notches their identical footing against the hexagon
// (two now land near a vertex, two near a flat), but they clear the tightest
// boundary by more than 10mm, so only the 90 degree spacing actually matters.
//
// The sign follows the fan's flow direction. Flipping the fan over mirrors the
// panel-plane position of its cable, so a reversed fan wants a negated angle.
//
// They open into the bore instead of being closed holes because the 4-pin
// connector has to be threaded through during assembly, and a closed hole wide
// enough for it would leave under a millimetre of material beside the M5 boss.
// In service the fan's own frame corner covers the opening, so it costs no
// airflow.
enable_fan_wire_slots = true;      // Toggle the cable notches in the fan web
fan_wire_slot_angle = 13;          // Degrees past the corner diagonal (cable exit is at 14.85)
fan_wire_slot_radius = 7;          // Radius of the notch disc
fan_wire_slot_reach = 6.4;         // How far the notch reaches outward past the bore edge
                                   // Tuned for the 92: a smaller fan puts its screws
                                   // proportionally closer to the bore and wants less.
fan_wire_slot_chamfer = 0.6;       // Edge break on both faces so the cable cannot chafe

// Asserted, not derived: the module measures the true distance from the notch to
// every fan screw countersink and refuses to render below this. Rotating the notch
// off the diagonal relieves it a lot -- 1.6mm at 0 degrees, 6.4mm at 15 -- so the
// guard has to measure rather than assume the screw sits straight outboard.
fan_wire_slot_clearance = 1.5;     // Minimum material between notch and screw countersink

// Radius and reach are independent: reach pins the outer edge, and the disc grows
// inward from there. So widening the notch opens it further along the bore edge
// without ever moving towards the screw boss -- at radius 7 the opening measures
// 14mm across where it crosses the bore, and whatever falls inside the bore edge
// is cutting empty space. It has to cross that edge, though: a radius below half
// the reach closes the notch into a separate hole, which the module rejects.

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

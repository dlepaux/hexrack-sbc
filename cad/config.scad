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
// Which board this case is built for. Assigned HERE, far from the rest of the board
// configuration, because back_depth below is derived from it and OpenSCAD resolves
// nothing forward at file scope -- a variable read above its assignment is undef,
// silently, and -D lands where the original assignment was. Same hazard, and the same
// fix, as face_vent_pattern and face_depth further down this file.
//   "rock5b+"          - Rock5b+
//   "rpi5_pironman"    - Pironman (Raspberry PI 5)
//   "bitaxe_naja_duo"  - Bitaxe Naja Duo + Coolserver LGA1700 heatsink
//   "empty"            - No board
drawer_board = "bitaxe_naja_duo";

// Back section depth. PER BOARD, because only one board needs the length.
//
// The Bitaxe Naja Duo is 147.000 x 90.000 (lib/naja-duo-base.scad) and the bore is a
// hexagon whose widest internal chord is body_width - 2*wall_thickness/cos(30) =
// 138.45mm. 147 therefore does not cross the case at ANY height, and no offset rescues
// it: that board can only lie with its long axis running front to back, which is what
// 160 buys. A Naja unit is ~200mm deep against ~155mm for the others, and is meant to
// sit at the bottom of a stack.
//
// The cost of per-board rather than one global depth: back-top and feet are derived
// from back_depth, so they stop being shareable and move into the per-board manifest
// groups (scripts/generate-stl.sh), and the published layout gains a board dimension
// (cad/layout-export.scad, manifest schemaVersion 4). face, fan and dust derive from
// face_depth/fan_depth instead, so those stay shared across every board.
// 160 for the Naja Duo is what the BOARD needs and nothing more -- it occupies section
// Y 12..159. The rear pull fan does NOT live in here; it has its own section, back-fan,
// with its own depth. See the REAR PULL FAN block further down.
function board_back_depth(model) =
    model == "bitaxe_naja_duo" ? 160 : 115;

back_depth = board_back_depth(drawer_board);
// Fan
fan_depth = 31; // Noctua 92mm

// --- Face section depth -----------------------------------------------------
// The face section holds the dust filter at its front and the vent panel at its back,
// so its depth is the sum of the two plus fit. It is DERIVED rather than typed, because
// the gyroid pattern needs a panel one full tunnel-turn deep and getting the two out of
// step leaves the panel either clipped or rattling.
//
// Sized for the SELECTED panel. This used to take max(face_thickness, gyroid_period), so
// every case was as deep as the gyroid needs (15.3mm) whatever pattern was chosen -- the
// flat patterns carried 9mm of dead plenum, and the case was 164.3mm instead of 155.3mm.
//
// The rejected argument for the max() was that a cosmetic choice must not change the case
// depth or units would not line up. It does not hold here: the vent pattern is a GLOBAL
// choice in the configurator, not per-unit, so a rack is all one depth either way. What it
// does mean is that depth is no longer one number -- caseDepth, the section offsets and the
// M4 stack screw all now depend on the pattern, and every one of them is derived from
// face_depth rather than typed, so they follow it. See cad/layout-export.scad.
//
// These must precede face_depth. OpenSCAD does NOT resolve forward references at file
// scope -- a variable used before its assignment reads as undef, SILENTLY. That is not
// theoretical here: with face_vent_pattern left at its old position further down this file,
// face_panel_thickness() below reads undef and quietly returns face_thickness for every
// pattern, gyroid included, and -D does not help because -D lands where the original
// assignment was.
dust_filter_depth = 4 - OVERLAP;   // sectionDust()'s default depth

// The dust filter's retaining ribs and the face's receiving grooves are ONE joint seen
// from two parts, so the plane they meet on is defined here and read by both. It is
// anchored to the FRONT of the case, where the filter actually seats.
//
// It must NEVER be anchored to face_depth. face_depth is sized for the deepest panel any
// pattern needs (below), so when the gyroid raised that from 2mm to 11mm, a groove written
// as "face_depth - 2" moved 9mm back and stopped meeting the rib at all -- on every
// pattern, gyroid included. Both parts still exported clean and the assembly still
// rendered; the joint had simply ceased to exist. scripts/test-dust-clip-fit.sh now
// measures the overlap instead of trusting it.
//
// dust_clip_clearance is how far behind the rib the groove sits, so the filter can slide
// in and the rib bite. tolerance + OVERLAP reproduces the fit the joint had before the
// gyroid: OVERLAP is a glue allowance dust_filter_depth subtracts at the BACK of the
// filter, and the seat at the front must not inherit it.
dust_clip_length    = 1.7;         // 45-degree rib, square section
dust_clip_y         = dust_filter_depth - sqrt(2) * dust_clip_length;
dust_clip_clearance = tolerance + OVERLAP;
face_thickness = 2;                // panel depth for voronoi / triangles / grid
// THE gyroid knob: how big one tunnel is. The panel is exactly one period deep, so this
// sets the case depth too -- there is no second knob and no free depth to choose.
//
// The panel MUST span a whole period. That is structural, not aesthetic: the gyroid's
// material is a single connected network only over a full period, and a partial slice
// cuts it into islands. Measured on this panel -- 1.0 turn: one body; 0.7: three bodies;
// 0.6: seven; 0.5: six. A fragmented panel still renders and exports clean, so nothing
// would have said so; scripts/test-vent-patterns.sh counts bodies for exactly this.
//
// NOT freely tunable, despite being a number. Whether the remaining web stays in ONE
// PIECE depends on how the cells happen to fall against the hexagon, its margin ring and
// the front circle -- and that does not vary smoothly. Measured, bodies as
// (front circle on / off):
//
//   period  8 -> 2 / 1      period 11 -> 1 / 1   <- the only value that holds both
//   period 10 -> 2 / 1      period 12 -> 2 / 1
//   period  9 -> 3 / -      period 13 -> 11 / 1
//
// A panel in two pieces renders and exports perfectly cleanly, so nothing in the build
// would say so -- it just falls apart coming off the bed. scripts/test-vent-patterns.sh
// counts bodies for every pattern crossed with the front circle. Change this number and
// run that test; do not assume a nearby value behaves like this one.
//
// At 11: 11mm panel, 164.3mm case, ~52,700 facets, 2.6MB, 2s.
face_vent_gyroid_period = 11;

// Which pattern the FRONT panel carries. Lives up here, not with the rest of the vent
// configuration, because face_depth below is derived from it -- see the ordering note above.
face_vent_pattern = "triangles";

// Panel depth for a given pattern. Only the gyroid varies through the depth, and it takes
// one whole period for the reason above.
function face_panel_thickness(mode = face_vent_pattern) =
    mode == "gyroid" ? face_vent_gyroid_period : face_thickness;

face_depth = dust_filter_depth + face_panel_thickness() + tolerance;
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
board_y_global_offset = -2;
preset_rock5b = [
  "rock5b+", 0, 0, -0.7 + board_y_global_offset, 0,
  49,
  0, 0.75, 0, 1,
  54, 20, 8, 0,
  10,
];

// Pironman Case Standoff: 5mm
preset_pironman = [
  "rpi5_pironman", 0, 40.5, -2.5 + board_y_global_offset, 0,
  28,
  -1.50, 0, -1, 0,
  40, 20, 0, 0,
  5,
];

// Bitaxe Naja Duo
//
// standoff_z_offset (field 5) is 40, and it is the knob for raising or lowering the
// WHOLE board -- PCB, heatsink and all. board_z = z_offset + wall_thickness +
// standoff_z_offset, so either of the two offsets moves the stack; the convention in
// this file is that standoff_z_offset carries the height and z_offset stays 0, which is
// what rock5b+ (49) and the Pironman (28) do.
//
// 40 is not a preference, it is close to the optimum. The board is 90mm across once
// rotated and the heatsink reaches 67.25mm above its datum with a backplate 11.2mm
// below, so a ~79mm stack has to thread a hexagon that narrows from its middle in both
// directions. 40 puts the PCB 19.95mm below the centreline, and the whole stack then
// clears by 7.84mm at its tightest (the fins, 48mm up). At 30 the same stack cleared by
// only 2.28mm, at the backplate. Sweeping every value, the best achievable is 7.94mm at
// 39.8 -- so 40 is within 0.1mm of the best this case can do.
//
// support_mandatory_standoff_height (the last field) is 20, not the 10 the other two
// boards use, and that one IS a hard floor. It is the gap between the printed canoe top
// and the board, and the XT30 power plug hangs 10.645mm under the board
// (naja_duo_underside_clearance). At 10 the canoe top stands above the bottom of the
// connector, so the support and the plug occupy the same space -- and the part still
// renders and exports perfectly cleanly, because the board is only a preview model and
// is never differenced against the supports. scripts/test-board-fit.sh asserts it.
//
// Rotation is +90 (get_board_rotation below), so the 147mm long axis runs along the
// case depth. See the back_depth note above for why there is no other option.
//
// y_offset is DERIVED, and that is load-bearing. back-bottom models itself from its far
// corner, so the board frame is flipped about back_depth -- which means a TYPED offset
// silently drags the board backwards every time the case gets deeper. Adding the rear
// pull fan's 30mm did exactly that: the board went from Y 12..159 to 42..189, jammed
// against the back panel with no room for the fan it had just been made deeper for, and
// the duct -- which stops at 42.27 -- was left reaching for a cooler that had moved out
// from under it. Everything still rendered and exported cleanly.
//
// The board is positioned from the FRONT, because that is the end that matters: the duct
// has to meet the cooler. So its front edge is pinned and the extra depth falls behind
// it, which is where the fan goes.
//
//   front edge = back_depth - (wall_thickness + effective_depth) - y_offset
//              = back_depth - 152 - y_offset
naja_board_front_y = 12;   // clear air between the fan section and the PCB's front edge
//
// To move the board again: change standoff_z_offset, then run
// ./scripts/test-board-fit.sh -- it walks the measured board and heatsink profiles
// against the hexagon's taper band by band and fails on both sides of the window.
preset_bitaxe_naja_duo = [
  "bitaxe_naja_duo", 0, 0, back_depth - 152 - naja_board_front_y, 0,
  38,
  0, 0, 0, 0,
  46, 20, 8, 0,
  20,
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
    // 92 = the board's 90mm rotated width plus a millimetre either side. The height
    // covers the PCB plus the XT30 hanging under it, not the fin stack -- the fins sit
    // well above the back panel's cutout band and want the vent pattern, not a blank.
    model == "bitaxe_naja_duo" ? [-11, 0, 24, 92] :
    [0, 0, 0];

// Board rotation (board-specific)
// Format: [x, y, z] rotation in degrees
function get_board_rotation(model) =
    model == "rock5b+" ? [0, 0, 0] :
    model == "rpi5_pironman" ? [0, 0, -90] :
    // The 90 is forced, not chosen: 147mm cannot cross a 138.45mm bore, so the long
    // axis has to run along the case depth.
    //
    // The SIGN is not free either, and it is not the -90 the Pironman uses. The board's
    // only masked connector is the USB-C power input on its x=0 edge, and back-face.scad
    // reaches the board through a frame flipped about y=0. Traced through that frame,
    // -90 lands the USB-C at y=-150 -- a metre and a half of case away from the panel it
    // has to breathe through, pointing at the fan instead. +90 lands it at y=-1. Both
    // render and export a perfectly clean case; only one has a hole where the plug goes.
    model == "bitaxe_naja_duo" ? [0, 0, 90] :
    [0, 0, 0];

// Natural board dimensions (before rotation)
// Used by setup.scad for visualization
// Both Naja Duo numbers are the Edge.Cuts extents straight from the .kicad_pcb, not a
// measurement -- see lib/naja-duo-base.scad for the commit they came from.
function get_natural_board_width(model) =
    model == "rock5b+" ? 100 :
    model == "rpi5_pironman" ? 85 :
    model == "bitaxe_naja_duo" ? 147 :
    100;  // Default width

function get_natural_board_depth(model) =
    model == "rock5b+" ? 75 :
    model == "rpi5_pironman" ? 95.83 :
    model == "bitaxe_naja_duo" ? 90 :
    85;  // Default depth

// ============================================================================
// HONEYCOMB VENTILATION
// ============================================================================
honeycomb_size = 10;               // Size of hexagon cells
honeycomb_wall_thickness = 1.5;    // Thickness of honeycomb walls

// ============================================================================
// DUST FILTER LABELS
// ============================================================================
// Engraved into the dust filter's front face, in the solid band between its outer and
// inner hexagons. That band is 8.6mm at the flats and its top edge is 69mm long
// (59mm at the inner hexagon), and the part prints lying flat with this face upward --
// so it is a top surface, which is the one place on the case that engraves cleanly.
//
// Replaces the old textover_* block, which drove components/textover.scad. That module
// labelled a drawer part which no longer exists, and called preset_textover() and
// preset_board_count(), neither of which has existed since the drawer was removed.
//
// Empty by default: a label is per-unit, so the pre-baked STLs on the website carry
// none. Set these when rendering locally.
dust_label_top = "";
dust_label_bottom = "";

// Liberation Sans is OpenSCAD's own default family, so it resolves on a bare CI runner.
// A missing font falls back silently rather than failing, so scripts/test-dust-label.sh
// asserts the label actually removes material instead of trusting it rendered.
dust_label_font = "Liberation Sans:style=Bold";
dust_label_size = 5;               // Cap height in mm; must fit the 8.6mm band
dust_label_depth = 1;              // Engraving depth in mm
// The limit is MILLIMETRES, not characters, and dustLabelCutter() derives it: the band's
// usable flat is 2*(band_mid - dust_label_size/2)*tan(30) = 61.2mm at these numbers.
// Character count is not a proxy -- "NODE-01-RACK-A-XY" and "NODE-01-RACK-ABCD" are both
// 17 characters and span 70.8mm and 74.1mm. An overlong label used to render exit-0 with
// an unchanged bounding box and its outer glyphs chipped off; it now trips an assert,
// provided OpenSCAD ran with --enable=textmetrics (the builtin is still experimental).

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
// Section snap lips
// ============================================================================
// Tongue-and-groove ring that joins two stacked body sections. The male tongue
// rides on a section's near face and enters the groove cut into the far face of
// the section ahead of it.
//
// This is an open rebate, not a closed groove: the female cutter reaches past the
// section's outer surface, so the tongue's OUTER face becomes the case's visible
// skin across the seam and must stay flush. The only locating surface is the
// tongue's inner face against the rebate, and lip_clearance is the gap there --
// a location fit that the M3 screws then clamp, not a press fit.
lip_wall        = 1.2;
lip_clearance   = 0.1;
lip_female_wall = lip_wall + lip_clearance;

// The rebate mouth is deliberately NOT chamfered: the locating band sits right at
// it, so breaking that edge would move the band inward and loosen the fit. The
// tongue arrives on a long 45-degree lead-in, so a sharp mouth is not a hazard.
//
// Gentle thinning of the tongue over the rebate, for easier entry. Zero on
// purpose: at 45 degrees every 0.1mm of taper is 0.1mm added straight to the seam
// gap (see lip_floor_ramp), and it buys nothing -- the tongue's tip is already a
// lip_floor_ramp-long 45-degree lead-in, which guides the joint far better than a
// 0.3mm taper spread over 3mm ever did. Raise it only if the joint binds on entry.
lip_taper       = 0;
// Thinnest the tongue's tip may get. It follows the ramp down until it hits this,
// and that is what stops it -- see lipMaleOverlap(). One extrusion width.
lip_tip_min     = 0.4;

// Axial relief: the rebate is cut this much deeper than the tongue is long. The
// two sections must seat on their annular faces, never on the tongue tip. Without
// it the tip lands on the rebate floor with one EPS to spare, so any elephant's
// foot -- or the small radius a nozzle always leaves in an internal corner --
// holds the joint open.
lip_floor_gap   = 0.3;

// The rebate is a step cut into the outer surface, so where it ends it leaves a
// square internal corner running right around the hexagon -- in profile:
//
//     outer surface      ____                  ____
//                       |          becomes    /
//     rebate face   ____|                ____/
//
// lip_floor_ramp fades the cut out over this length instead.
//
// It also sets the gap left on show at each seam. The ramp brings the section's
// face back out at lip_female_wall / lip_floor_ramp per mm and the tongue has to
// retreat at the same rate to clear it, so the tongue runs out of wall first:
//
//     lipSeamGap() = lip_floor_ramp x (lip_clearance + lip_taper + lip_tip_min)
//                                     -------------------------------------
//                                              lip_female_wall
//
// Set to lip_female_wall the ramp is exactly 45 degrees -- the usual FDM overhang
// limit, and what this face needs if the print puts it underneath -- and the
// formula collapses to
//
//     lipSeamGap() = lip_clearance + lip_taper + lip_tip_min  =  0.5mm
//
// independent of lip_wall and of the ramp length. So at 45 degrees those three are
// the only levers, and two of them are physics: lip_clearance IS the fit, and
// lip_tip_min is one extrusion width. 0.5mm is the floor; the tongue cannot be
// lengthened past it because there is no wall left to print. Shorter ramps close
// the seam proportionally but steepen the face and eat the seating margin, and 0
// closes the seam entirely at the cost of a square corner.
lip_floor_ramp  = lip_female_wall;

// NOT a tunable knob, despite being named. The 3mm lip depth is also baked into
// eleven other literals that were derived from it by hand and do not reference
// it: the half-section trim cubes (back-bottom.scad:51-52 as `- 3` and `+ 3`,
// back-top.scad:35), the fan's 3mm web and its cable notches (fan.scad:24, 27,
// 55), the intercase dovetail rail offsets (back-top.scad:76 as 1.1 / -3.1), the
// back-face dovetail pass-through (back-face.scad:152), and the rear screw
// patterns (back-bottom.scad:166, 183 and back-top.scad:95 as `-wall_thickness - 3`).
// Changing this alone leaves those stale and silently ships a half-clipped tongue
// that renders clean and only fails on the printer. Retuning the depth for real
// means auditing all twelve together.
// ponytail: depth hardcoded across 12 sites; wire the derived literals to this
// constant if the joint depth ever actually needs to move.
lip_depth       = 3;

// ============================================================================
// Canoe
// ============================================================================
// Tolerance for treating two X values as "the same column"
canoe_group_tol   = 0.5;
// Extra width beyond the insert boss diameter (0 = exactly boss width)
canoe_wall        = 0.0;
// How far the canoe runs past the outermost holes. The supports are intersected
// with the part envelope, so anything >= the part depth makes the canoe span the
// full part — one continuous rail, fused to both walls, for a stronger print.
canoe_overrun     = back_depth;
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
body_part = "assembly";
bodyAssembly_space = 0;
bodyAssembly_back_space = 0;

back_mounting_brackets_bevel_size = 10;
back_mounting_brackets_width=10;
back_mounting_brackets_back_width=back_mounting_brackets_width*3;
back_mounting_brackets_height=10;
back_mounting_brackets_depth=25;

back_face_thickness=3;

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

// drawer_board is assigned up in BODY DIMENSIONS, because back_depth is derived from
// it. See the ordering note there.

drawer_preset =
  drawer_board == "rock5b+" ? preset_rock5b
  : drawer_board == "rpi5_pironman" ? preset_pironman
  : drawer_board == "bitaxe_naja_duo" ? preset_bitaxe_naja_duo
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
show_sides_support=true;

// Highlight the section snap lips (#) in preview. They are normally invisible in
// body_part="assembly": bodyAssembly_space is 0, so each section sits flush against
// its neighbour and every tongue is swallowed by the neighbour's rebate. To actually
// look at a lip, render ONE section -- body_part="fan" is the clearest -- or set
// bodyAssembly_space above 0 to pull the stack apart.
debug_lips = false;

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

// The pattern the BACK face carries. It can never be the gyroid: that panel is
// back_face_thickness (3mm) and a gyroid needs a whole period of depth or its web falls
// into separate pieces -- rendering back-face with gyroid selected gives FIVE bodies.
//
// Enforced here, in the geometry, and not only in scripts/lib/variant-matrix.sh. The
// build script resolves the fallback before it renders, so the published STLs were always
// right; but anyone opening cad/body.scad with gyroid selected got a back panel in five
// pieces that exported perfectly cleanly. Now the substitution is part of the model, so
// the gyroid is a front-face pattern at every entry point.
function back_face_vent_pattern(mode = face_vent_pattern) =
    mode == "gyroid" ? "triangles" : mode;
// face_vent_pattern itself is assigned near face_depth, which is derived from it.

// Solid rim kept inside the hexagon edge, measured at the flats. Load-bearing,
// not cosmetic: a gyroid strand runs the full width of the panel, so with
// nothing tying the two halves together it saws the face into separate bodies
// the moment enable_front_circle stops filling the ring outside the fan bore.
face_vent_margin = 3;

// -- gyroid ------------------------------------------------------------------
// THE ONE KNOB is face_vent_gyroid_period, up in BODY DIMENSIONS because the face
// section's depth derives from it: a tunnel only completes its turn if the panel is one
// whole period deep, so cell size and panel depth are the same number and cannot be set
// independently without breaking the effect.
//
// Everything below is fixed by the committed asset and is not a tuning surface.
//
// The tunnels come from assets/gyroid-tunnels.stl, meshed offline by
// scripts/generate-gyroid-asset.py. The previous implementation solved a 2D slice in
// closed form and stacked the slices as prisms, which is bounded by real mathematics:
// that solution exists only while |sin(phase)| <= sqrt(1/2), capping a panel at 90
// degrees of sweep -- a QUARTER turn, at any thickness or period. A tunnel that turns
// needs a genuine isosurface, which OpenSCAD cannot mesh, so it is meshed once and
// imported. Same approach as assets/voronoi_svg.svg and assets/noctua-92.stl.

// The asset is normalised to one period per unit, so the physical cell size is a
// scale(). These three describe what was actually generated; changing one without
// regenerating the asset silently mis-sizes the pattern, so vent-patterns.scad asserts
// the panel fits inside them.
face_vent_gyroid_asset = "../assets/gyroid-tunnels.stl";
face_vent_gyroid_asset_cells = [20, 18];  // periods spanned in X and Z
face_vent_gyroid_asset_depth = 1.4;       // periods spanned in Y; > 1 so the tunnels
                                          // break through both faces of the panel

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
// COOLER DUCT (fan section)  -- bitaxe_naja_duo only
// ============================================================================
// The Naja Duo runs with its Coolserver heatsink's OWN 60mm fan removed, so the 92mm
// Noctua is the only fan in the case. This duct is what makes that work: it grows off
// the back of the fan section's web and carries the bore's air straight onto the fin
// stack, into the opening the cooler's fan vacated.
//
// Every number here is measured off the assets through the real board transform, not
// eyeballed -- see scripts/test-board-fit.sh for the same technique. In the section
// frame (X across the case, Y back from the fan web, Z up from the case floor):
//
//   92mm bore centre .......... (75.00, 0.00, 64.95)
//   cooler fan frame .......... 60.0 x 60.0 x 25.4, centred (74.98, 84.80),
//                               front face Y = 16.27, fin face just behind it
//   its four mounting screws .. 50.0 x 50.0 pitch about the same centre
//
// The fan frame measures 60.000 x 60.000 on the nose and its screws sit on the standard
// 50mm square, which is the useful part: the duct is aimed at a real fan footprint, not
// an approximation, and can eventually be screwed into those same four holes.
//
// So the duct has ~16mm to go from a 92mm circle to a 60mm square while climbing
// 19.85mm. It is a short converging shroud, not a long tube.
//
// ONLY the Naja Duo has a cooler, so duct_enabled() is board-gated -- and that is what
// makes the fan section board-specific where it used to be shared across all three
// boards. Same trade as back-top and feet; see the back_depth note.
function duct_enabled(model = drawer_board) = model == "bitaxe_naja_duo";

// THE ADJUSTABLE KNOB. The duct's mouth is the fan bore with a segment taken off its
// BOTTOM; this is how tall that opening is. Everything the duct does not swallow spills
// through it, down past the board, and becomes the under-board plenum where the stick-on
// 6x6x6 copper heatsinks live.
//
// A chord rather than a concentric ring, and that is deliberate on three counts. The
// duct now meets the bore edge around the top and sides, so it is fused to the web and
// needs no vanes holding it in mid-air. The spill is aimed DOWNWARD, at the board,
// instead of leaking evenly in all directions. And the same opening gives the 92mm fan's
// cable somewhere to go -- see duct_cable_* below.
//
// 0 would close it and send everything to the fins; 46 (the bore radius) would open the
// whole lower half. scripts/test-cooler-duct.sh reports the resulting area split.
duct_bleed_height   = 16;

// Where the duct goes, along the case depth, measured from the fan section's rear face.
//
// The nozzle length is the correction that matters: the duct used to stop at 15, which
// is SHORT OF the cooler entirely -- the fan's pocket does not begin until 16.27. Air
// left the duct into open case and had to find the fins on its own. The duct now runs
// through that pocket, occupying the space the fan came out of, and stops just shy of
// the fin face at 43.12.
duct_transition_length = 16.27;  // bore -> square, and the climb from Z 64.95 to 84.80
duct_nozzle_length     = 26.0;   // straight through the pocket, to Y 42.27
duct_fit_clearance     = 0.4;    // per side, so the nozzle slides into a 60.000 pocket

// The nozzle, matched to the fan footprint it replaces. 60.000 x 60.000 is what the fan
// frame actually measures, so the nozzle is that less two clearances and slides into the
// pocket the fan came out of.
duct_outlet_size    = 60;
duct_outlet_radius  = 6;       // corner rounding
duct_outlet_z       = 84.80;   // fan frame centre height, measured
duct_wall           = 2;       // one perimeter pair

// Measured from the asset, and recorded rather than left to be re-derived: the cooler's
// own fan screws sit on a 50.0 x 50.0 square about the outlet centre. Nothing uses these
// yet -- the plan is to screw the duct into those four holes in place of the fan, once
// the fit has been adjusted and tested on a real print.
duct_screw_pitch    = 50.0;

// ============================================================================
// REAR PULL FAN (back face)  -- bitaxe_naja_duo only
// ============================================================================
// The front 92mm fan pushes; this one pulls, so the miner gets a through-draught rather
// than a plenum that has to find its own way out. It screws to the INSIDE of the back
// face, which is already a per-board part, so it costs no new section and no new lips.
//
// It lives in its OWN SECTION, back-fan, sitting between the back and the back face --
// the mirror of the front fan section, with the same tongue-and-groove lips, the same
// 2.6mm shell and the same web carrying the bore and the screw square. Its predecessor
// bolted the fan inside a back section deepened to 190, which worked but put a fan, a
// board and a duct in one part and made back_depth mean two different things.
//
// back_depth is therefore back to 160 -- what the BOARD needs, and nothing more -- and
// the fan's depth is its own number.
//
// The stack, front to back:
//   dust | face | fan | back-bottom + back-top | back-fan | back-face
//
// Same bore and same 82.5 screw square as the front section, deliberately: one spare fan
// fits either end, and the pattern is already proven to clear the hexagon at this size.
// The 2.6mm shell is copied from the front for the same reason -- at wall_thickness the
// hexagon closes in on the fan's corners by another 2.7mm.
function rear_fan_enabled(model = drawer_board) = model == "bitaxe_naja_duo";

back_fan_depth    = 31;              // mirrors fan_depth; 25mm fan plus the web
back_fan_wall     = 2.6;             // mirrors the front fan section's shell
rear_fan_bore     = fan_size_mode;   // tracks the front fan

// ============================================================================
// USB-C PANEL MOUNT (back face)  -- bitaxe_naja_duo only
// ============================================================================
// With the pull fan filling the back face, the board's own USB-C no longer reaches the
// outside: J4 sits at section Y 159 pointing straight at the fan, 31mm behind the panel.
// A riser cable runs from it to a panel-mount USB-C socket, and this is that socket's
// cutout.
//
// It goes in the band BELOW the fan bore. That band is what is left of the hexagon under
// a 92mm circle centred on the case: Z 5..18.95, about 14mm tall and 77mm wide at its
// middle. Tight, which is why the screw ears are placed BESIDE the opening rather than
// above and below it -- the usual panel-mount footprint stands the ears vertically and
// will not fit in 14mm.
//
// Defaults are for a common panel-mount USB-C extension. Measure yours before printing:
// this is the one part here whose dimensions come from a catalogue rather than from an
// asset in this repo, so it is the one most likely to be wrong.
usbc_panel_z          = 12;      // opening centre, above the case floor
usbc_panel_width      = 13;      // receptacle shell opening
usbc_panel_height     = 7;
usbc_panel_radius     = 1.5;     // corner rounding on the opening
usbc_panel_screw_pitch = 22;     // ear to ear, horizontal
usbc_panel_screw_dia  = 2.6;     // M2.5 clearance

// ============================================================================
// FAN CABLE ROUTE (through the duct skirt)
// ============================================================================
// The 92mm fan's cable leaves its frame through one of the four notches in the web
// (fan_wire_slot_*) and then has to reach the board. Before the duct that was open case;
// now the duct fills the bore, so without a passage the cable would either be pinched
// under the skirt or end up inside the airway, flapping against the fins.
//
// The bleed chord is already an opening in the bottom of the skirt, so the cable uses
// it: this channel is a local widening of that opening, at the bottom, sized for the
// 4-pin connector rather than the bare wires -- the connector has to pass during
// assembly, and a hole sized for the cable means cutting the plug off.
//
// Placed at the bottom, deliberately NOT on a wire-slot angle. The notches sit at
// +-(45 + fan_wire_slot_angle) from vertical, so the cable arrives near the lower
// corners either way and reaches the bottom by the shortest path; putting the channel
// on a notch would instead pin the design to a fan rotation the user cannot control.
duct_cable_width    = 12;   // clears a 4-pin Molex/JST shell
duct_cable_height   = 7;



// The outlet is a SQUARE and the inlet a circle, so the shell is built by hulling the
// two profiles and subtracting a second hull inset by duct_wall. Doing it the other way
// -- extruding a shell along a path -- leaves the corners open where the circle becomes
// a square.

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

function contains(arr, val) = len([for (i = arr) if (i == val) i]) > 0;

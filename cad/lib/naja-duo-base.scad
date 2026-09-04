// ============================================================================
// NAJA DUO BASE - Bitaxe Naja Duo + Coolserver LGA1700 heatsink
// ============================================================================
// The Naja Duo is not in SBC_Model_Framework, so everything the framework would
// normally answer -- outline, mounting holes, connector masks -- is stated here.
//
// Same shape as lib/pironman-base.scad, and for the same reason: sbc-helpers.scad
// and the sections dispatch on the board model, and a board the framework does not
// know needs one file that owns its geometry.
//
// Usage: najaDuoBase(enablemask=false)
//   enablemask = false: visual models (PCB + heatsink)
//   enablemask = true:  connector masks only (for back panel cutouts)
// ============================================================================

include <../config.scad>

// ============================================================================
// SOURCE OF TRUTH
// ============================================================================
// Every number below was read out of the KiCad PCB, not measured off a render:
//
//   github.com/bitaxeorg/naja-duo  BitaxeNajaDuo.kicad_pcb
//   commit c095459b491c3eae36542e8a9753840903bd2005  ("Rename hardware revision
//   to 1201", 2026-08-28), rev 1201, CERN-OHL-S v2.
//
// PIN THAT SHA. The board's own README calls rev 1201 "an untested prototype",
// so the hole pattern is not settled upstream. If the case ever stops fitting,
// diff the Edge.Cuts and the MountingHole footprints against this commit before
// touching anything here.
//
// KiCad stores Y pointing DOWN from an arbitrary page origin. Positions here are
// in the board frame the rest of this project uses -- bottom-left corner, Y up,
// PCB bottom face at Z=0, which is also SBC_Model_Framework's pcb() convention:
//
//   x_board = x_kicad - 60.499999
//   y_board = 147.976103 - y_kicad
//
// Cross-checked against assets/BitaxeNajaDuo.stl, whose bounding box is
// x 60.500..207.500 and y -147.976..-57.976 -- the same 147.000 x 90.000 to four
// decimal places, from an independently exported artefact.
naja_duo_kicad_commit = "c095459b491c3eae36542e8a9753840903bd2005";

// ============================================================================
// BOARD OUTLINE
// ============================================================================
// One (gr_rect ... (radius 3.5)) on Edge.Cuts -- a KiCad-10 rounded rectangle,
// no internal cutouts, no slots.
naja_duo_width  = 147.000;   // X
naja_duo_depth  = 90.000;    // Y
naja_duo_radius = 3.5;       // corner radius

// (general (thickness 1.6)), and the six-layer stackup sums to 1.600 exactly.
// assets/BitaxeNajaDuo.stl disagrees at 1.510; the .kicad_pcb wins, because the
// STL is a visual and this number is not.
naja_duo_pcb_thickness = 1.6;

// How far the board's own hardware reaches below its bottom face. The XT30 power
// plug (J1) is the deepest thing on the underside. Measured off the STL, which is
// the only artefact that carries connector bodies at all -- the .kicad_pcb has
// footprints, not heights.
naja_duo_underside_clearance = 10.645;

// ============================================================================
// MOUNTING HOLES -- H1..H4
// ============================================================================
// MountingHole:MountingHole_3.2mm_M3_Pad_Via, plated, Ø3.2 drill on a Ø6.4 GND
// pad, ringed by eight Ø0.5 stitching vias.
//
// The pitch is a clean 140.000 x 83.000 and the left/right insets are 3.5 -- that
// roundness is what confirms the frame conversion above is right. The Y insets are
// 3.476 and 3.524 rather than a matched pair: the outline's Y range is not on a
// 0.5mm grid while the holes are on integers. That 0.048 asymmetry is real and is
// carried through rather than tidied away, so the holes stay where the board's
// holes actually are.
naja_duo_hole_diameter = 3.2;
naja_duo_hole_pad_diameter = 6.4;   // grounded copper -- a metal standoff is fine

naja_duo_mounting_holes = [
  [  3.500001,  3.476103 ],   // H3
  [143.500001,  3.476103 ],   // H1
  [  3.500001, 86.476103 ],   // H4
  [143.500001, 86.476103 ],   // H2
];

function get_naja_duo_mounting_holes() = naja_duo_mounting_holes;

// Accessors, because sbc-helpers.scad reaches this file through `use` and `use`
// imports functions but not variables.
function naja_duo_hole_d() = naja_duo_hole_diameter;

// ============================================================================
// HEATSINK
// ============================================================================
// The MountingHole:"cpu mounting" footprint -- four oval NPTH slots, drill
// 3.2 x 5.8, on a 76.5 x 76.5 pitch, centred here. The long axis of each slot runs
// radially outward at 45 degrees, giving 2.6mm of float: this is the clamp that
// holds the heatsink down onto both BM1340 ASICs, and it is NOT what holds the
// board in the case. That is H1..H4 above.
naja_duo_heatsink_center = [97.330001, 44.976103];
naja_duo_heatsink_pitch  = 76.5;

// assets/Coolserver LGA1700 R64 v22.stl is modelled in METRES -- its bounding box
// is 0.090 x 0.092 x 0.078 -- so it needs scale(1000). Left unscaled it imports as
// a 0.09mm speck that renders and exports perfectly cleanly and is invisible in a
// 150mm case, which is precisely the kind of silent wrong this comment exists to
// prevent.
naja_duo_heatsink_asset = "../assets/Coolserver LGA1700 R64 v22.stl";
naja_duo_heatsink_scale = 1000;

// Quarter turn about Z. The clamp posts sit on a symmetric 76.5 square so they still
// land in the board's four slots either way -- what the rotation actually decides is
// which way the fin channels and heat pipes run, and therefore whether the 92mm fan
// blows along them or across them.
//
// It is not free geometrically. The fin stack is not square: across the hexagon it
// measures at most 93.15mm unrotated and 89.89mm rotated, and the case decides the fit
// on roughly 2mm, so the quarter turn is worth about a millimetre of clearance. The
// profile below is measured on the ROTATED asset and only valid for this value --
// change it and re-measure, do not assume the numbers carry over.
naja_duo_heatsink_rotation = 90;

// The cooler ships with a 60mm fan and this build does not use it -- the 92mm Noctua
// feeds the fins through a duct instead. This box is where that fan is.
//
// IT CANNOT BE SUBTRACTED IN OPENSCAD. The asset is an open surface ("Input mesh is not
// closed"), so any difference() against it fails Manifold conversion and collapses the
// WHOLE object to empty -- the cooler vanishes rather than losing its fan. Same reason
// scripts/test-board-fit.sh checks against proxies instead of the meshes themselves.
//
// So the box is a PREVIEW volume: shown in the model with #, positioned by editing the
// two corners below, and applied for real by scripts/strip-cooler-fan.py, which deletes
// the triangles that fall inside it and rewrites the STL.
//
// ALREADY APPLIED. The committed asset has had its fan cut out with exactly this box --
// 11670 triangles, 4.1% -- so the preview is off and the box is kept only so the cut is
// reproducible and adjustable. Re-running the script on the stripped file is a no-op;
// use --restore to get the fan back first.
//
// The only measurement the cut moved was naja_duo_heatsink_above, 67.250 -> 67.000. The
// profile below did NOT change: the fan is 60mm across the hexagon where the fins are
// ~90, so it never set the width at any band.
//
// Starting point, measured off the asset: the fan frame is X -30.00..30.00,
// Y -45.40..-20.00, Z 7.25..67.25 and the fins do not begin until Y = -18.55, so there
// is 1.45mm of clear air to cut in. Grown slightly past the frame to take the rotor and
// the protruding part of the four fan screws with it -- they come out with the fan.
naja_duo_show_fan_box = false;                                // preview the box
naja_duo_fan_box  = [[-31, -46.5, 6.0], [31, -19.0, 68.5]];   // [min, max], asset frame

// The pocket the fan leaves behind, in the asset frame, and where it lands once the
// board transform is applied. section_Y = asset_Y + 61.67 for this board's placement,
// which is what turns the fan frame into a pocket at section Y 16.27..41.67 with the fin
// face at 43.12. cad/config.scad sizes the duct's nozzle from these.
naja_duo_fan_pocket_y   = [16.27, 41.67];   // section frame
naja_duo_fin_face_y     = 43.12;            // section frame

// Where the asset's own z=0 sits above the PCB's BOTTOM face.
//
// The asset's z=0 is NOT its lowest point and NOT the PCB surface: it is the top of the
// cold plate, whose contact face is 0.15mm below it (a 36.4 x 27 pad at z -0.15..0),
// with the backplate and clamp posts reaching to -11.2 because they pass through the
// board. Placing the asset at the PCB top face therefore buries the cold plate inside
// the 1.6mm PCB slab and lays the heat pipes on the board surface -- which is exactly
// how this was wrong before.
//
// The cold plate has to land on the ASIC dies, so the datum is PCB + die + plate.
// 0.795 is measured off assets/BitaxeNajaDuo.stl at both BM1340 positions, and it is
// also the tallest thing anywhere under the cooler's footprint -- nothing else on the
// board's top face intrudes, so seating on the dies is collision-free as well as
// correct. The fan headers, the tallest top-side parts at 9.1mm, sit outside it.
naja_duo_asic_height        = 0.795;   // die top above the PCB top face
naja_duo_heatsink_plate_gap = 0.15;    // asset z=0 down to the cold plate's face
naja_duo_heatsink_datum =
    naja_duo_pcb_thickness + naja_duo_asic_height + naja_duo_heatsink_plate_gap;

// The asset's RAW scaled bounds, about its own z=0 datum -- not about the PCB. These
// are what scripts/test-board-fit.sh asserts the mesh still measures, so they stay in
// the asset's unrotated frame even though it is placed rotated; the rotation swaps the
// two size components at the point of use.
naja_duo_heatsink_above = 67.000;   // fin stack, above the datum (67.250 with its fan on)
naja_duo_heatsink_below = 11.200;   // backplate + clamp posts, below the datum
naja_duo_heatsink_size  = [89.888, 91.543];

// The board is rotated 90 degrees in the case (get_board_rotation), so it is the
// BOARD'S Y axis that crosses the hexagon and its X axis that runs along the case
// depth. The depth is a straight extrusion and constrains nothing; only Y is squeezed.
// Profiling the wrong axis is an easy and expensive mistake -- by X the fin stack looks
// like it tapers from 89.9mm to 65.1mm and clears everything, by Y it is 90.8mm nearly
// all the way up and the fit is decided by roughly 2mm.
//
// So both profiles below are, per 2mm band, the FULL WIDTH ACROSS THE HEXAGON:
// 2 * max|y - centre|, measured off the meshes. Not a bounding box, and not an extent
// either -- a band whose material sits off-centre needs the room its far edge needs.
// scripts/test-board-fit.sh walks these against the hexagon's taper band by band.

// PCB, including every component on both faces. z is measured from the PCB's
// BOTTOM face, so negative bands are the underside hardware.
//   [ z from PCB bottom, width across the hexagon ]
naja_duo_pcb_profile = [
  [ -12.0,  68.594 ], [ -10.0,  79.898 ], [  -8.0,  85.848 ], [  -6.0,  84.148 ],
  [  -4.0,  85.848 ], [  -2.0,  84.018 ], [   0.0,  90.000 ], [   2.0,  86.152 ],
  [   4.0,  74.348 ], [   6.0,  76.448 ], [   8.0,  79.898 ], [  10.0,  79.496 ],
];

// Heatsink, AS ROTATED by naja_duo_heatsink_rotation. z is measured from the asset's
// own datum (naja_duo_heatsink_datum above), so the negative bands are the backplate
// and clamp posts passing through the board.
//   [ z from the cooler datum, width across the hexagon ]
naja_duo_heatsink_profile = [
  [ -12.0,  88.381 ], [ -10.0,  89.729 ], [  -6.0,  81.800 ], [  -2.0,  81.860 ],
  [   0.0,  82.880 ], [   2.0,  89.888 ], [   4.0,  89.888 ], [   6.0,  88.216 ],
  [   8.0,  89.156 ], [  10.0,  89.685 ], [  12.0,  89.700 ], [  14.0,  87.545 ],
  [  16.0,  89.685 ], [  18.0,  89.123 ], [  20.0,  88.863 ], [  22.0,  87.212 ],
  [  24.0,  84.530 ], [  26.0,  80.509 ], [  28.0,  71.506 ], [  30.0,  89.700 ],
  [  32.0,  89.422 ], [  34.0,  89.123 ], [  36.0,  87.456 ], [  38.0,  84.985 ],
  [  40.0,  81.975 ], [  42.0,  89.679 ], [  44.0,  89.117 ], [  46.0,  87.168 ],
  [  48.0,  87.451 ], [  50.0,  84.745 ], [  52.0,  81.104 ], [  54.0,  76.667 ],
  [  56.0,  71.581 ], [  58.0,  68.427 ], [  60.0,  68.271 ], [  62.0,  66.202 ],
  [  64.0,  66.000 ], [  66.0,  65.127 ],
];

// LONGITUDINAL profile: how tall and how deep the board is along its OWN X axis, which
// is the case's depth once the board is rotated. Per 3mm band: [x, top z, bottom z], both
// in the mesh's frame where the PCB slab is 0..1.510.
//
// A second profile, and not redundant with naja_duo_pcb_profile: that one answers "how
// WIDE is the board at this height", extruded along the whole length, which is exactly
// right for the hexagonal bore (where depth is unconstrained) and exactly wrong for the
// duct. The duct passes over the FRONT of the board on its way up to the cooler, so the
// question there is "how tall is the board AT THIS POINT ALONG ITS LENGTH".
//
// Using the wrong one reports a 6.19mm collision where the board is bare copper: the
// front 20mm (x 130..147) carries nothing above the top face at all, and the tallest
// thing in the first 60mm is the 0.795mm ASICs.
//   [ x from the board origin, top z, bottom z ]
naja_duo_pcb_length_profile = [
  [   0.0,   1.510,   -3.395 ], [   3.0,   1.510,   -3.395 ], [   6.0,   1.510,   -3.395 ],
  [   9.0,  -0.085,   -0.885 ], [  12.0,  10.595,   -9.905 ], [  15.0,  10.595,   -9.905 ],
  [  18.0,  10.595,   -9.905 ], [  21.0,  10.595,   -9.905 ], [  24.0,  10.595,   -9.905 ],
  [  27.0,  10.595,   -9.905 ], [  30.0,  10.595,   -9.905 ], [  33.0,  10.595,   -9.905 ],
  [  36.0,  10.595,   -9.905 ], [  39.0,  10.595,  -10.645 ], [  42.0,  10.595,  -10.645 ],
  [  45.0,   9.845,   -9.721 ], [  48.0,   2.885,  -10.645 ], [  51.0,  -0.085,  -10.645 ],
  [  54.0,   1.510,    0.000 ], [  57.0,   1.510,   -1.605 ], [  60.0,   1.510,   -1.605 ],
  [  63.0,   1.510,   -7.276 ], [  66.0,  -0.085,   -1.605 ], [  69.0,  -0.085,   -1.185 ],
  [  72.0,  -0.085,   -1.685 ], [  75.0,  -0.085,   -7.273 ], [  81.0,   2.305,   -0.585 ],
  [  84.0,   2.305,   -1.085 ], [  87.0,   2.305,   -1.085 ], [  90.0,   2.305,   -1.635 ],
  [  93.0,   2.305,   -1.635 ], [  96.0,   2.295,   -1.635 ], [  99.0,   2.305,   -1.635 ],
  [ 102.0,   2.305,   -1.085 ], [ 105.0,   2.305,   -0.885 ], [ 108.0,   2.305,   -1.635 ],
  [ 111.0,   2.295,   -1.635 ], [ 114.0,  -0.085,   -1.635 ], [ 132.0,   1.510,    0.000 ],
  [ 135.0,   1.510,    0.000 ], [ 138.0,   1.510,    0.000 ], [ 141.0,   1.510,    0.000 ],
  [ 144.0,   1.510,    0.000 ], [ 147.0,   1.510,    0.000 ],
];

// ============================================================================
// CONNECTORS
// ============================================================================
// Positions from the footprints' (at ...), converted to the board frame. Only J4
// gets a mask: it is the one connector that has to breathe through a case wall.
//
// J4 -- USB-C 2.0 receptacle (GCT USB4105-GF-A), on the BOTTOM side, rotated 90,
// its mouth flush with the board's left edge (body starts 0.020 inside the
// outline, courtyard overhangs to -0.485). This is the power input.
naja_duo_usbc_y      = 24.986103;  // opening centre along the board's left edge
naja_duo_usbc_width  = 8.940;      // body width across the opening
naja_duo_usbc_height = 3.300;      // USB-C receptacle body height (spec, not in the PCB file)

// The planned Ethernet module has no position yet -- it is going ON TOP of the
// board and has not been designed. Nothing is cut for it. Deliberately absent
// rather than guessed: a hole in the wrong place is worse than no hole, and the
// back panel is a 3mm plate that is cheap to reprint once the module exists.
// ponytail: no Ethernet cutout until the module exists; revisit with its outline.

// The rest, for whoever needs them next. Not masked, not cut, listed so the
// positions do not have to be re-derived from the .kicad_pcb:
//   J1  XT30 power, 2-pin, UNDERSIDE, pads (43.750, 13.376) and (48.750, 13.376)
//   J7/J8/J9  Molex 0470531000 fan headers, TOP, y=5.376, x=40.890/17.770/29.330
//   J2  30-pin 0.5mm FPC display ribbon, UNDERSIDE, (30.155, 69.976)
//   SW1/SW2  tact switches, TOP, y=86.576, x=33.900/22.400
//   U6  ESP32-S3-WROOM-1; its antenna keepout is x 0.110..6.860, y 37.826..55.826
//       on the underside -- keep screws, standoffs and metal out of that box.

// ============================================================================
// MASKS
// ============================================================================
mask_depth_naja = 10;

// USB-C opening. A plain rounded slot rather than a socket-shaped pocket -- the
// receptacle is 1mm behind the panel's inner face, so the panel only has to let the
// plug through, not locate it.
//
// The slot sits ENTIRELY BELOW the board's bottom face (z from -slot_h to 0), which
// is where J4 actually is: it is a bottom-side part, so its body hangs under the PCB
// rather than straddling it. Centring the slot on the board plane instead would put
// half the opening in the board's own thickness and clip the bottom of the plug.
//
// Sized for the plug, not the receptacle: 9.74 x 4.1 against a USB-C plug body of
// 8.34 x 2.56. The overmould is larger than that and stays outside, butting on the
// panel -- normal for a 3mm panel, and the reason the recess was kept to 1mm.
module najaDuoUsbcMask(depth = mask_depth_naja) {
  slot_h = naja_duo_usbc_height + 2 * tolerance;
  slot_w = naja_duo_usbc_width + 2 * tolerance;

  translate([-depth, naja_duo_usbc_y, -slot_h / 2])
    rotate([0, 90, 0])
      linear_extrude(depth + OVERLAP)
        offset(r = slot_h / 2)
          square([EPS, slot_w - slot_h], center = true);
}

// ============================================================================
// MAIN MODULE
// ============================================================================
// Drawn in the board frame: PCB from (0,0,0) to (147, 90, 1.6), components up.
// Parameters:
//   enablemask - true emits connector masks, false emits the visual models
module najaDuoBase(enablemask = false) {
  if (enablemask) {
    color("purple", 0.6)
      najaDuoUsbcMask();
  } else {
    // PCB. The asset is exported in KiCad's own page frame with Y negated, so the
    // same two constants that convert the hole positions place the mesh.
    color("green", 0.8)
      translate([-60.499999, 147.976103, 0])
        import("../assets/BitaxeNajaDuo.stl");

    // Heatsink, sitting on the ASICs. Centred on the clamp pattern, its contact
    // plane on the PCB's top face.
    translate([naja_duo_heatsink_center[0],
               naja_duo_heatsink_center[1],
               naja_duo_heatsink_datum])
      rotate([0, 0, naja_duo_heatsink_rotation]) {
        color("silver", 0.7)
          scale(naja_duo_heatsink_scale)
            import(naja_duo_heatsink_asset);

        // The fan-removal box, as a preview only -- see the note above for why it
        // cannot be a difference(). Drag the two corners until it wraps the fan.
        if (naja_duo_show_fan_box)
          #translate(naja_duo_fan_box[0])
            cube([naja_duo_fan_box[1][0] - naja_duo_fan_box[0][0],
                  naja_duo_fan_box[1][1] - naja_duo_fan_box[0][1],
                  naja_duo_fan_box[1][2] - naja_duo_fan_box[0][2]]);
      }
  }
}

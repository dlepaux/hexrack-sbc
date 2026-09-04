include <../../config.scad>
use <../../lib/shapes.scad>
use <../../components/fan.scad>
use <../../components/mounting-holes.scad>
use <../../components/dovetails.scad>

// ============================================================================
// BACK FAN SECTION -- bitaxe_naja_duo only
// ============================================================================
// The mirror of sections/body/fan.scad, at the other end of the case. The front 92mm
// fan pushes into the cooler duct; this one pulls, so the miner gets a through-draught
// instead of a plenum that has to find its own way out.
//
// It is a section rather than a fan bolted inside the back, which is where this started.
// That version worked but made back_depth mean two things at once -- the board's length
// AND the fan's -- and put a board, a duct and a fan in one printed part. back_depth is
// now 160 because that is what the board needs; this section carries its own depth.
//
// The stack, front to back:
//   dust | face | fan | back-bottom + back-top | back-fan | back-face
//
// SAME LIPS AS THE FRONT, and that is the whole point of making it a section: the male
// tongue on its near face enters the back section's groove, and its own groove receives
// the back face's tongue. Nothing about the joint is new, so nothing about it needs
// re-testing beyond the existing scripts/test-lip-fit.sh.
//
// The 2.6mm shell is copied from the front section rather than using wall_thickness. It
// is not cosmetic: at 5mm the inner hexagon closes from 144 to 138.45 point-to-point and
// the fan's corners lose another 2.7mm of clearance they do not have to spare.
// ============================================================================

module sectionBackFan() {
  body_height = hex_flat_to_flat(body_width);

  difference() {
    union() {
      translate([0, 0, (-body_width + body_height) / 2])
        honeycomb_shell(body_width, back_fan_depth, back_fan_wall);

      // Male tongue, into the back section's groove.
      honeycombLipMale();

      // The web the fan bolts to, at the REAR face -- the fan pulls air out of the case
      // through it. The front section puts its web at the same relative place, so the
      // two parts are the same shape and print the same way up.
      translate([0, back_fan_depth - 3, 0])
        intersection() {
          translate([0, 0, (-body_width + body_height) / 2])
            honeycomb_box(body_width, 3, 0);

          translate([0, 0, (-body_width + body_height) / 2])
            roundedPanel(
              body_width,
              wall_thickness,
              corner_radius,
              0,
              center_hole = rear_fan_bore
            );
        }
    }

    // Female groove, receiving the back face's tongue.
    honeycombLipFemale(back_fan_depth);

    // Assembly screws, straight through, same pattern as every other section.
    translate([0, -OVERLAP * 5, 0])
      frontfaceMountingHolesFront(type = "through", body_height = body_height);

    // Fan mounting screws. Same frame the front section uses, so the two patterns cannot
    // drift apart -- one spare fan has to fit either end.
    translate([0, 0, (-body_width + body_height) / 2])
      rotate([0, 0, 180])
        translate([-body_width, -back_fan_depth, 0])
          fanMountingHoles();

    // Cable exits, one per corner so any of the fan's four rotations works. Identical to
    // the front section's, and for the same reason: the fan lands on the web's corners
    // and its cable has no way through otherwise.
    if (enable_fan_wire_slots)
      translate([0, back_fan_depth - 3, (-body_width + body_height) / 2])
        fanWireSlots(
          size = body_width,
          thickness = 3,
          bore = rear_fan_bore,
          screw_offset = fan_screw_offset(fan_size_mode),
          radius = fan_wire_slot_radius,
          reach = fan_wire_slot_reach,
          angle = fan_wire_slot_angle,
          clearance = fan_wire_slot_clearance,
          chamfer = fan_wire_slot_chamfer
        );

    // Intercase dovetail channels, carried straight through.
    //
    // Needed for the same reason back-face.scad carries them: a neighbouring case's rail
    // is slid in from the REAR, and anything in the way stops it. Without this the rail
    // reaches the back face's pass-through, meets this section and goes no further, and
    // the only way to tile two cases is to take the back off first.
    //
    // The channels do breach this section's 2.6mm shell where they run -- they are ~2.5mm
    // deep. That is accepted rather than fixed by thickening the wall: this section is a
    // plenum, a slot near its corners costs a little leakage and nothing structural,
    // where wall_thickness would cost the fan 2.7mm of corner clearance it needs more.
    // ponytail: shell breached by the dovetail channels; revisit if the section flexes.
    for (face = ["bottom", "bottom-left", "bottom-right"]) {
      if (contains(dovetail_intercase, face)) {
        dovetailIntercase(face, "female", body_height, -3 - EPS,
                          back_fan_depth + 3 + 2 * EPS);
      }
    }
  }

  if (show_fan) {
    %translate([body_width / 2, back_fan_depth, body_height / 2])
      fanVisualization92();
  }
}

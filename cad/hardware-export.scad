// ============================================================================
// HARDWARE EXPORT
// ============================================================================
// Emits how many of each fastener one case takes, counted from the same position lists
// the geometry cuts its holes from.
//
// scripts/generate-stl.sh used to write these into the manifest by hand, and they drifted:
// it published four M4 and eight M3 screws per case against the two of each the CAD cuts,
// and four inserts for every board when the Pironman adapter adds three more. Counting
// here means a hole added to a pattern is a screw added to the build sheet.
//
// Usage: openscad -o out.echo --export-format=echo -D 'drawer_board="rock5b+"' \
//          cad/hardware-export.scad
// ============================================================================

include <config.scad>
use <lib/shapes.scad>
use <lib/sbc-helpers.scad>
use <components/mounting-holes.scad>
use <SBC_Model_Framework/sbc_models.scad>
include <SBC_Model_Framework/sbc_models.cfg>

body_height = hex_flat_to_flat(body_width);

echo(str("HEXRACK_HARDWARE",
         " board=",        drawer_board,
         // M4 through the front sections, nut in the back halves' traps
         " stack=",        len(frontface_mounting_positions(body_height)),
         // M3 from the back face into the back halves, on the same pattern
         " backPanel=",    len(frontface_mounting_positions(body_height)),
         " fanScrews=",    len(fan_mounting_positions()),
         // One heat-set insert per supported board hole, adapter holes included
         " inserts=",      len(get_sbcMountingHoles(drawer_board)),
         " antennaPosts=", len(antenna_sides)));

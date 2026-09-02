// ============================================================================
// LAYOUT EXPORT
// ============================================================================
// Emits the assembly geometry the website needs, straight from the CAD.
//
// scripts/generate-stl.sh used to write these into the manifest as literals, which
// silently went stale the moment face_depth changed -- and face_depth is derived, so it
// moves whenever the gyroid's cell size does. Reading them from here means the published
// layout cannot disagree with the parts it describes.
//
// Usage: openscad -o /dev/null --export-format=echo cad/layout-export.scad
// ============================================================================

include <config.scad>
use <lib/shapes.scad>

body_height = hex_flat_to_flat(body_width);
back_y      = face_depth + fan_depth;

echo(str("HEXRACK_LAYOUT",
         " pointToPoint=",  body_width,
         " flatToFlat=",    body_height,
         " caseDepth=",     back_y + back_depth + back_face_thickness,
         " dust=",          0,
         " face=",          0,
         " fan=",           face_depth,
         " backBottom=",    back_y,
         " backTop=",       back_y,
         " backFace=",      back_y + back_depth,
         " feetDrop=",      body_height / 2,
         " columnPitch=",   body_width * 3 / 4,
         " rowPitch=",      body_height));

// ============================================================================
// PIRONMAN BASE - Raspberry Pi 5 + Pironman 5 Max Adapter Assembly
// ============================================================================
// Module for rendering Raspberry Pi 5 with Pironman 5 Max HDMI/USB-C adapter.
// Supports both visual model and connector masks for drawer integration.
//
// Usage: pironmanBase(enablemask=false)
//   enablemask = false: Show visual models (Pi + adapter STL)
//   enablemask = true:  Show connector masks only (for front panel cutouts)
// ============================================================================

use <../SBC_Model_Framework/sbc_models.scad>
include <../SBC_Model_Framework/sbc_models.cfg>

pironman_offset_for_nvme=7;

// ============================================================================
// CONNECTOR MASK MODULES (Extracted from SBC_Model_Framework)
// ============================================================================

function isPironman(model) =
  model == "rpi5_pironman" || model == "rpi5_pironman_core" || model == "rpi5_pironman_apps" || model == "rpi5_pironman_dual";

// Slot helper (from shape.scad)
module slot(hole, length, depth) {
  hull() {
    translate([hole / 2, 0, 0]) cylinder(d=hole, h=depth, $fn=30);
    translate([length - hole / 2, 0, 0]) cylinder(d=hole, h=depth, $fn=30);
  }
}

// HDMI Type A mask (from video.scad)
module hdmiMask(depth = 10) {
  union() {
    difference() {
      translate([.25, -5, 1]) cube([15, depth, 5.75]);
      translate([0.5, -5.2, .5]) rotate([-90, 0, 0]) cylinder(d=3, h=depth + 1, $fn=30);
      translate([15, -5.2, .5]) rotate([-90, 0, 0]) cylinder(d=3, h=depth + 1, $fn=30);
    }
    translate([2, -5, .5]) cube([11.5, depth, .5]);
  }
}

// USB-C horizontal mask (from usbc.scad)
module usbcMask(depth = 10) {
  size_x = 9;
  size_xm = 10;
  dia = 3.5;
  diam = 4.5;

  translate([0, -depth, 0])
    rotate([90, 0, 0])
      slot(diam, size_xm, depth);
}

// ============================================================================
// PIRONMAN BASE MODULE
// ============================================================================

// Adapter positioning (measured from draft testing)
pironman_adapter_x = 43;
pironman_adapter_y = -20.3;
pironman_adapter_z = 2.5;
pironman_adapter_rotation = [0, 0, 0];

// Connector positions (measured from draft testing)
mask_depth = 10;
pironman_connector_offset_x = 87 + 3.2;
pironman_connector_offset_y = 10;
pironman_hdmi_offset_z = pironman_adapter_z + 17.85;

pironman_hdmi1_x = pironman_connector_offset_x;
pironman_hdmi1_y = -pironman_connector_offset_y - 1.85;
pironman_hdmi1_z = pironman_hdmi_offset_z;
pironman_hdmi1_rotation = [0, 90, 90];

pironman_hdmi2_x = pironman_connector_offset_x;
pironman_hdmi2_y = -pironman_connector_offset_y - 14.35;
pironman_hdmi2_z = pironman_hdmi_offset_z;
pironman_hdmi2_rotation = [0, 90, 90];

pironman_usbc_x = pironman_connector_offset_x - mask_depth - 5;
pironman_usbc_y = -pironman_connector_offset_y - 28 - 0.5;
pironman_usbc_z = pironman_adapter_z + 2.65;
pironman_usbc_rotation = [0, 0, 90];

// ============================================================================
// ADAPTER MOUNTING HOLES
// ============================================================================
// Module for Pironman adapter-specific mounting holes (3 holes)
// These are in addition to the Pi5's 4 standard mounting holes
// The adapter holes are 3mm higher than the Pi5 board level
pironman_mounting_holes_x_base = -4.05;
pironman_mounting_holes_x = -32.50;
pironman_adapter_z_offset = 3; // Adapter holes are 3mm higher than Pi5 holes

// Adapter mounting hole positions (X, Y, Z coordinates)
// Z is relative offset from Pi5 board level (0 for Pi5 holes, 3mm for adapter holes)
positions = [
  [3.45, pironman_mounting_holes_x_base + pironman_mounting_holes_x, pironman_adapter_z_offset],
  [61.5, pironman_mounting_holes_x_base + pironman_mounting_holes_x, pironman_adapter_z_offset],
  [61.5, pironman_mounting_holes_x_base, pironman_adapter_z_offset],
];

// Function to get adapter mounting hole positions
// Returns: Array of [x, y, z] positions for the 3 adapter holes
// Z values are relative offsets from Pi5 board level
function get_pironman_adapter_holes() = positions;

module adapterMountingHoles() {
  hole_diameter = 2.7; // 3.2mm clearance hole
  hole_depth = 50; // Deep enough to cut through bottom panel

  color("blue", 0.6) // Blue to distinguish from Pi5 holes
  for (pos = positions) {
    translate([pos[0], pos[1], -hole_depth + 3.75])
      cylinder(d=hole_diameter, h=hole_depth, center=false, $fn=32);
  }
}

// Main pironman_base module
// Parameters:
//   enablemask - true shows connector masks, false shows visual models
module pironmanBase(enablemask = false) {
  if (enablemask) {
    // === MOUNTING HOLES ===

    // Pi5 mounting holes (4 standard holes from framework)
    color("red", 0.6)
      sbc(model="rpi5", enablemask=true);

    // Adapter mounting holes (3 additional holes)
    adapterMountingHoles();

    // === CONNECTOR MASKS ===
    // HDMI Port 1
    color("orange", 0.6)
      translate([pironman_hdmi1_x, pironman_hdmi1_y, pironman_hdmi1_z])
        rotate(pironman_hdmi1_rotation)
          hdmiMask(depth=mask_depth);

    // HDMI Port 2
    color("orange", 0.6)
      translate([pironman_hdmi2_x, pironman_hdmi2_y, pironman_hdmi2_z])
        rotate(pironman_hdmi2_rotation)
          hdmiMask(depth=mask_depth);

    // USB-C Power Port
    color("purple", 0.6)
      translate([pironman_usbc_x, pironman_usbc_y, pironman_usbc_z])
        rotate(pironman_usbc_rotation)
          usbcMask(depth=mask_depth);
  } else {
    // Visual models (Pi + adapter)
    // Raspberry Pi 5
    sbc(model="rpi5", enablemask=false);

    // Pironman adapter STL
    translate([pironman_adapter_x, pironman_adapter_y, pironman_adapter_z])
      rotate(pironman_adapter_rotation)
        import("../assets/pironman-5-max-hdmi-usbc-adapter.stl");
  }

  // Dual NVMe Board
  // translate([0, -40.1 - pironman_offset_for_nvme, 1.7 + 18])
  translate([0, -40.1 - pironman_offset_for_nvme, 1.7 + 18])
  color("green", 0.3)
  cube([85, 45, 1.5]);

  // GPIO Extender
  translate([7.5, 53, 0])
  color("green", 0.3)
  cube([50, 2, 68.5]);
}

/**
 * Configuration → where each published STL sits in the assembled rack.
 *
 * Every part is exported in its own section frame, and the manifest's `partOffsetY` says how
 * far back cad/body.scad places it, so composing a rack is only translation: the grid centre
 * in X/Z, the section offset in Y. No mesh is inspected, which is what lets the preview frame
 * the rack before a single file has loaded.
 *
 * Coordinates are CAD millimetres, +Z up, with the lowest ground unit's bottom flat at
 * Z = -flatToFlat/2. The renderer owns the conversion to its own axes.
 */

import type { Manifest, PartSlot } from '../types/manifest';
import { centre, deriveRack, parseCellKey, type CellKey } from './rack';
import { type RackConfig, unitParts } from './resolve';

export interface Placement {
  /** Stable per unit and slot, so React keeps a mesh when only its file changes. */
  key: string;
  cell: CellKey;
  slot: PartSlot;
  file: string;
  position: [number, number, number];
}

export interface PreviewLayout {
  placements: Placement[];
  bounds: { min: [number, number, number]; max: [number, number, number] };
}

export function layoutRack(manifest: Manifest, config: RackConfig): PreviewLayout {
  const { gridPitch, hex, byVentPattern, feet } = manifest.layout;
  const pattern = byVentPattern[config.ventPattern];
  if (!pattern) throw new Error(`layoutRack: no layout for vent pattern '${config.ventPattern}'`);

  const pitch = { column: gridPitch.column, row: gridPitch.row };
  const { cells } = deriveRack(config.units, pitch);
  const placements: Placement[] = [];
  const min: [number, number, number] = [Infinity, 0, Infinity];
  const max: [number, number, number] = [-Infinity, pattern.caseDepth, -Infinity];

  for (const [cell, unit] of config.units) {
    const d = cells.get(cell);
    if (!d) continue;

    // Parts are exported from their section's corner, so the unit's origin is its centre
    // less half the hexagon on each axis.
    const c = centre(parseCellKey(cell), pitch);
    const x = c.x - hex.pointToPoint / 2;
    const z = c.z - hex.flatToFlat / 2;

    min[0] = Math.min(min[0], x);
    max[0] = Math.max(max[0], x + hex.pointToPoint);
    min[2] = Math.min(min[2], d.feet ? z - feet.drop : z);
    max[2] = Math.max(max[2], z + hex.flatToFlat);

    // A part the build lacks is left out here; the build sheet is what reports it.
    for (const p of unitParts(manifest, config, unit, d)) {
      if (!p.found) continue;
      placements.push({
        key: `${cell}/${p.slot}`,
        cell,
        slot: p.slot,
        file: p.found.file,
        position: [x, pattern.partOffsetY[p.slot], z],
      });
    }
  }

  return { placements, bounds: { min, max } };
}

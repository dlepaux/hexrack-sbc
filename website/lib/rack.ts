/**
 * The rack grid, and everything that derives from it.
 *
 * Cases tile as a honeycomb, so where a unit sits determines which of its six faces
 * meet a neighbour — and that alone determines which dovetail variant of each part it
 * needs. The user places units; nobody picks `top-left` versus `bottom-right`.
 *
 * COORDINATES. Axial (q, r), flat-top hexagon, matching the CAD's +Z-up world:
 *
 *     x(q, r) = 112.5 · q                    (¾ × the 150mm point-to-point width)
 *     z(q, r) = 129.9038 · (r + q/2)         (the 150·cos30 flat-to-flat height)
 *
 * Verified against STL bounding boxes: body-face.stl spans X 0…150.00 and Z 0…129.90,
 * so vertices sit left and right and the top and bottom edges are horizontal.
 * A renderer drawing in screen space (y down) negates z.
 */

import type { Face, FemaleFace, MaleFace } from '../types/manifest';

export interface Axial {
  q: number;
  r: number;
}

export type CellKey = string;

export const cellKey = (c: Axial): CellKey => `${c.q},${c.r}`;

export function parseCellKey(k: CellKey): Axial {
  const [q, r] = k.split(',').map(Number);
  return { q, r };
}

/**
 * The six neighbours. `face` is the edge on THIS unit; `mate` is the edge the neighbour
 * presents back. Male faces carry a protruding rail, female faces a groove — the
 * asymmetry that matters: an unmatched rail is a physical interference, an unmatched
 * groove is only an open channel.
 */
export const DIRECTIONS = [
  { dq: 0, dr: 1, face: 'top', mate: 'bottom', gender: 'male' },
  { dq: 1, dr: 0, face: 'top-right', mate: 'bottom-left', gender: 'male' },
  { dq: -1, dr: 1, face: 'top-left', mate: 'bottom-right', gender: 'male' },
  { dq: 0, dr: -1, face: 'bottom', mate: 'top', gender: 'female' },
  { dq: -1, dr: 0, face: 'bottom-left', mate: 'top-right', gender: 'female' },
  { dq: 1, dr: -1, face: 'bottom-right', mate: 'top-left', gender: 'female' },
] as const satisfies ReadonlyArray<{
  dq: number;
  dr: number;
  face: Face;
  mate: Face;
  gender: 'male' | 'female';
}>;

export const MALE_FACES: readonly MaleFace[] = ['top', 'top-right', 'top-left'];
export const FEMALE_FACES: readonly FemaleFace[] = ['bottom', 'bottom-left', 'bottom-right'];

export interface Unit {
  board: string;
  antennas: boolean;
  /**
   * Engraved into the dust filter's front face. Empty means no engraving, which is the
   * only case the published body-dust.stl covers -- anything else has to be cut in the
   * browser. Required rather than optional so the compiler names every place a unit is
   * built, and see lib/labels.ts for what a label may contain: it is spliced into an
   * OpenSCAD -D argument.
   */
  labelTop: string;
  labelBottom: string;
}

export interface Derived {
  /** Faces carrying a rail — selects the Back Top variant. */
  male: MaleFace[];
  /** Faces carrying a groove — selects Back Bottom AND Back Face, which must agree. */
  female: FemaleFace[];
  /** Whether this unit needs the Feet part. See `deriveRack`. */
  feet: boolean;
}

export interface RackWarning {
  cell: CellKey;
  message: string;
}

export interface RackDerivation {
  cells: Map<CellKey, Derived>;
  warnings: RackWarning[];
}

/** Position of a unit's centre in CAD millimetres, +Z up. */
export function centre(c: Axial, pitch: { column: number; row: number }) {
  return { x: pitch.column * c.q, z: pitch.row * (c.r + c.q / 2) };
}

/** Keys of the six neighbours of a cell, in DIRECTIONS order. */
export function neighbourKeys(c: Axial): CellKey[] {
  return DIRECTIONS.map((d) => cellKey({ q: c.q + d.dq, r: c.r + d.dr }));
}

/**
 * Derive every unit's dovetail sets and feet requirement.
 *
 * FEET are not "the bottom unit's stand" — they bridge a half-column offset. Adjacent
 * columns are staggered by half a case, so a ground unit in the lowest column rests on
 * its own 75mm flat bottom edge and needs nothing, while one in a staggered column sits
 * `rowPitch/2` up and needs a foot that drops exactly that far. `cad/showcase.scad`
 * imports body-feet.stl only under the half-offset Rock 5B+, under neither on-grid Pi5.
 *
 * A ground unit more than one half-step above the lowest is a layout the single existing
 * foot cannot reach; that warns rather than silently emitting feet.
 */
export function deriveRack(
  units: ReadonlyMap<CellKey, Unit>,
  pitch: { column: number; row: number },
): RackDerivation {
  const cells = new Map<CellKey, Derived>();
  const warnings: RackWarning[] = [];

  const ground: Array<{ key: CellKey; z: number }> = [];

  for (const key of units.keys()) {
    const c = parseCellKey(key);
    const male: MaleFace[] = [];
    const female: FemaleFace[] = [];
    let hasBelow = false;

    for (const d of DIRECTIONS) {
      if (!units.has(cellKey({ q: c.q + d.dq, r: c.r + d.dr }))) continue;
      if (d.gender === 'male') male.push(d.face as MaleFace);
      else {
        female.push(d.face as FemaleFace);
        if (d.face === 'bottom') hasBelow = true;
      }
    }

    cells.set(key, { male, female, feet: false });
    if (!hasBelow) ground.push({ key, z: centre(c, pitch).z });
  }

  if (ground.length > 0) {
    const zmin = Math.min(...ground.map((g) => g.z));
    const half = pitch.row / 2;
    for (const g of ground) {
      const rise = g.z - zmin;
      if (rise <= 1e-6) continue;
      cells.get(g.key)!.feet = true;
      if (rise > half + 1e-6) {
        warnings.push({
          cell: g.key,
          message:
            `sits ${rise.toFixed(1)}mm above the lowest unit, but the foot only drops ` +
            `${half.toFixed(1)}mm — this unit has nothing to stand on`,
        });
      }
    }
  }

  return { cells, warnings };
}

/** Units reachable from the first one. A rack in two pieces is two racks. */
export function connectedComponent(units: ReadonlyMap<CellKey, Unit>): Set<CellKey> {
  const seen = new Set<CellKey>();
  const first = units.keys().next();
  if (first.done) return seen;

  const stack: CellKey[] = [first.value];
  while (stack.length > 0) {
    const key = stack.pop()!;
    if (seen.has(key)) continue;
    seen.add(key);
    for (const nk of neighbourKeys(parseCellKey(key))) {
      if (units.has(nk) && !seen.has(nk)) stack.push(nk);
    }
  }
  return seen;
}

/** Every empty cell adjacent to a placed unit — the slots the user can click. */
export function openSlots(units: ReadonlyMap<CellKey, Unit>): CellKey[] {
  const slots = new Set<CellKey>();
  for (const key of units.keys()) {
    for (const nk of neighbourKeys(parseCellKey(key))) {
      if (!units.has(nk)) slots.add(nk);
    }
  }
  return [...slots];
}

/**
 * Stable A, B, C… labels, ordered top-to-bottom then left-to-right on screen, so a
 * label does not jump to a different unit when an unrelated one is added.
 */
export function unitLabels(
  units: ReadonlyMap<CellKey, Unit>,
  pitch: { column: number; row: number },
): Map<CellKey, string> {
  const ordered = [...units.keys()]
    .map((key) => ({ key, ...centre(parseCellKey(key), pitch) }))
    .sort((a, b) => b.z - a.z || a.x - b.x);

  const labels = new Map<CellKey, string>();
  ordered.forEach((o, i) => {
    labels.set(o.key, i < 26 ? String.fromCharCode(65 + i) : `U${i + 1}`);
  });
  return labels;
}

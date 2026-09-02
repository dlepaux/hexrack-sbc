/**
 * The shareable configuration link.
 *
 * Compact on purpose -- this is meant to be pasted into a chat. Lifted out of the
 * configurator when labels arrived, because the hash stopped being a convenience and
 * became a TRUST BOUNDARY: a label decoded from it is spliced into an OpenSCAD -D
 * argument, so anything arriving here is re-sanitised rather than believed.
 *
 * COMPATIBILITY runs both ways, and has to. A link shared before engraving existed has
 * four-element unit tuples, and is read as "no label". A link shared now carries six, and
 * older deployed copies of this page drop the extra two because they destructure the first
 * four -- they render the rack without the engraving instead of failing to open.
 */

import { cellKey, type CellKey, type Unit } from './rack';
import { engravedLabel } from './labels';

/** [q, r, board, antennas, labelTop?, labelBottom?] -- the tail is omitted when unlabelled. */
type UnitTuple = [number, number, string, 0 | 1] | [number, number, string, 0 | 1, string, string];

interface UrlState {
  u: UnitTuple[];
  v: string;
  c: 0 | 1;
}

export interface DecodedState {
  units: Map<CellKey, Unit>;
  vent: string;
  circle: boolean;
}

export function encodeState(
  units: ReadonlyMap<CellKey, Unit>,
  vent: string,
  circle: boolean,
): string {
  const state: UrlState = {
    u: [...units.entries()].map(([k, unit]) => {
      const [q, r] = k.split(',').map(Number);
      const ant: 0 | 1 = unit.antennas ? 1 : 0;
      const top = engravedLabel(unit.labelTop);
      const bottom = engravedLabel(unit.labelBottom);
      return top === '' && bottom === ''
        ? [q, r, unit.board, ant]
        : [q, r, unit.board, ant, top, bottom];
    }),
    v: vent,
    c: circle ? 1 : 0,
  };
  return btoa(JSON.stringify(state)).replace(/=+$/, '');
}

/** A hand-edited or truncated hash is expected, not exceptional -- it decodes to null and the caller falls back to a preset. */
export function decodeState(hash: string): DecodedState | null {
  try {
    const parsed: unknown = JSON.parse(atob(hash));
    if (typeof parsed !== 'object' || parsed === null) return null;
    const s = parsed as Partial<UrlState>;
    if (!Array.isArray(s.u) || s.u.length === 0 || typeof s.v !== 'string') return null;

    const units = new Map<CellKey, Unit>();
    for (const entry of s.u) {
      if (!Array.isArray(entry) || entry.length < 4) return null;
      const [q, r, board, ant, top, bottom] = entry;
      if (typeof q !== 'number' || typeof r !== 'number' || typeof board !== 'string') return null;
      units.set(cellKey({ q, r }), {
        board,
        antennas: ant === 1,
        // Re-sanitised, not trusted: this is the one path by which a stranger's text
        // reaches an OpenSCAD -D argument.
        labelTop: engravedLabel(typeof top === 'string' ? top : ''),
        labelBottom: engravedLabel(typeof bottom === 'string' ? bottom : ''),
      });
    }
    return { units, vent: s.v, circle: s.c === 1 };
  } catch {
    return null;
  }
}

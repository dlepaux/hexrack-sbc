import { describe, expect, it } from 'vitest';
import { cellKey, type CellKey, type Unit } from './rack';
import { decodeState, encodeState } from './url-state';

const unit = (over: Partial<Unit> = {}): Unit => ({
  board: 'rock5b+',
  antennas: false,
  labelTop: '',
  labelBottom: '',
  ...over,
});

const units = (...entries: Array<[number, number, Partial<Unit>?]>): Map<CellKey, Unit> =>
  new Map(entries.map(([q, r, over]) => [cellKey({ q, r }), unit(over)]));

/** Builds a hash the way an older deployment of this page did, before labels existed. */
const legacyHash = (u: Array<[number, number, string, 0 | 1]>, v: string, c: 0 | 1): string =>
  btoa(JSON.stringify({ u, v, c })).replace(/=+$/, '');

describe('round trip', () => {
  it('carries a labelled rack there and back', () => {
    const original = units([0, 0, { labelTop: 'NODE 01', labelBottom: 'RACK A' }], [0, 1]);
    const decoded = decodeState(encodeState(original, 'voronoi', false));
    expect(decoded).not.toBeNull();
    expect(decoded?.vent).toBe('voronoi');
    expect(decoded?.circle).toBe(false);
    expect([...(decoded?.units ?? [])]).toEqual([...original]);
  });

  it('omits the label fields entirely when there is nothing engraved', () => {
    // Keeps the common link short, and is what makes an older page able to read it.
    const hash = encodeState(units([0, 0]), 'triangles', true);
    const parsed = JSON.parse(atob(hash)) as { u: unknown[][] };
    expect(parsed.u[0]).toHaveLength(4);
  });
});

describe('compatibility', () => {
  it('reads a link shared before engraving existed', () => {
    const decoded = decodeState(legacyHash([[0, 0, 'rock5b+', 1]], 'triangles', 1));
    expect(decoded?.units.get('0,0')).toEqual(unit({ antennas: true }));
  });

  it('leaves a labelled link readable by a page that predates labels', () => {
    // An older bundle destructures the first four elements; the extra two are ignored, so
    // it renders the rack without the engraving rather than failing to open.
    const hash = encodeState(units([0, 0, { labelTop: 'NODE 01' }]), 'triangles', true);
    const parsed = JSON.parse(atob(hash)) as { u: Array<[number, number, string, 0 | 1]> };
    const [q, r, board, ant] = parsed.u[0];
    expect([q, r, board, ant]).toEqual([0, 0, 'rock5b+', 0]);
  });
});

describe('the hash is untrusted input', () => {
  // It is the one path by which a stranger's text reaches an OpenSCAD -D argument, so a
  // hand-edited link must not be able to smuggle anything past the allowlist.
  it('re-sanitises a label that was tampered with', () => {
    const hash = btoa(
      JSON.stringify({ u: [[0, 0, 'rock5b+', 0, 'X"; assert(false); z="', '']], v: 'triangles', c: 1 }),
    ).replace(/=+$/, '');
    expect(decodeState(hash)?.units.get('0,0')?.labelTop).toBe('X assert(false) z');
  });

  it('trims a label that is only whitespace', () => {
    const hash = btoa(
      JSON.stringify({ u: [[0, 0, 'rock5b+', 0, '   ', '']], v: 'triangles', c: 1 }),
    ).replace(/=+$/, '');
    expect(decodeState(hash)?.units.get('0,0')?.labelTop).toBe('');
  });

  it('ignores a label of the wrong type instead of crashing', () => {
    const hash = btoa(
      JSON.stringify({ u: [[0, 0, 'rock5b+', 0, 42, null]], v: 'triangles', c: 1 }),
    ).replace(/=+$/, '');
    expect(decodeState(hash)?.units.get('0,0')).toEqual(unit());
  });

  it('rejects junk rather than throwing', () => {
    expect(decodeState('not-base64!')).toBeNull();
    expect(decodeState(btoa('[]'))).toBeNull();
    expect(decodeState(btoa(JSON.stringify({ u: [], v: 'triangles', c: 1 })))).toBeNull();
    expect(decodeState(btoa(JSON.stringify({ u: [[0, 0]], v: 'triangles', c: 1 })))).toBeNull();
  });
});

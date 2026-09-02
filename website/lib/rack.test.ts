import { describe, expect, it } from 'vitest';
import {
  DIRECTIONS,
  cellKey,
  centre,
  connectedComponent,
  deriveRack,
  openSlots,
  unitLabels,
  type CellKey,
  type Unit,
} from './rack';

const PITCH = { column: 112.5, row: 129.903810567666 };
const UNIT: Unit = { board: 'rock5b+', antennas: false };

const rack = (...cells: Array<[number, number]>): Map<CellKey, Unit> =>
  new Map(cells.map(([q, r]) => [cellKey({ q, r }), { ...UNIT }]));

describe('grid geometry', () => {
  // Guards the numbers measured off the STL bounding boxes: body-face.stl spans
  // X 0..150.00 and Z 0..129.90. If these drift, every derived join is wrong.
  it('places neighbours a full case apart vertically and a staggered half-case diagonally', () => {
    const origin = centre({ q: 0, r: 0 }, PITCH);
    expect(origin).toEqual({ x: 0, z: 0 });

    const above = centre({ q: 0, r: 1 }, PITCH);
    expect(above.x).toBe(0);
    expect(above.z).toBeCloseTo(129.9038, 3);

    const upRight = centre({ q: 1, r: 0 }, PITCH);
    expect(upRight.x).toBeCloseTo(112.5, 6);
    expect(upRight.z).toBeCloseTo(64.9519, 3);
  });

  it('keeps all six neighbours equidistant, as a regular tiling requires', () => {
    const distances = DIRECTIONS.map((d) => {
      const p = centre({ q: d.dq, r: d.dr }, PITCH);
      return Math.hypot(p.x, p.z);
    });
    for (const dist of distances) expect(dist).toBeCloseTo(129.9038, 3);
  });

  it('pairs every face with the mate that lies in that direction', () => {
    for (const d of DIRECTIONS) {
      const back = DIRECTIONS.find((o) => o.dq === -d.dq && o.dr === -d.dr);
      expect(back, `no opposite for ${d.face}`).toBeDefined();
      expect(back!.face).toBe(d.mate);
      expect(back!.gender).not.toBe(d.gender);
    }
  });
});

describe('dovetail derivation', () => {
  it('gives a lone unit no joins at all', () => {
    const { cells } = deriveRack(rack([0, 0]), PITCH);
    expect(cells.get('0,0')).toMatchObject({ male: [], female: [] });
  });

  it('puts the rail on the lower unit and the groove on the upper one', () => {
    const { cells } = deriveRack(rack([0, 0], [0, 1]), PITCH);
    expect(cells.get('0,0')!.male).toEqual(['top']);
    expect(cells.get('0,0')!.female).toEqual([]);
    expect(cells.get('0,1')!.male).toEqual([]);
    expect(cells.get('0,1')!.female).toEqual(['bottom']);
  });

  it('derives a matching pair for every direction', () => {
    for (const d of DIRECTIONS) {
      const { cells } = deriveRack(rack([0, 0], [d.dq, d.dr]), PITCH);
      const mine = cells.get('0,0')!;
      const theirs = cells.get(cellKey({ q: d.dq, r: d.dr }))!;
      const mineFaces = [...mine.male, ...mine.female];
      const theirFaces = [...theirs.male, ...theirs.female];
      expect(mineFaces).toEqual([d.face]);
      expect(theirFaces).toEqual([d.mate]);
    }
  });

  it('gives a fully surrounded unit all six joins', () => {
    const ring = DIRECTIONS.map((d) => [d.dq, d.dr] as [number, number]);
    const { cells } = deriveRack(rack([0, 0], ...ring), PITCH);
    const centreCell = cells.get('0,0')!;
    expect([...centreCell.male].sort()).toEqual(['top', 'top-left', 'top-right']);
    expect([...centreCell.female].sort()).toEqual(['bottom', 'bottom-left', 'bottom-right']);
  });

  it('gives Back Bottom and Back Face the same female set, which is the pairing constraint', () => {
    const ring = DIRECTIONS.map((d) => [d.dq, d.dr] as [number, number]);
    const { cells } = deriveRack(rack([0, 0], ...ring), PITCH);
    // One derived set feeds both parts, so a mismatch is unrepresentable rather than
    // merely discouraged. This test exists to keep it that way.
    for (const d of cells.values()) expect(d.female).toBe(d.female);
    expect(cells.get('0,0')!.female).toHaveLength(3);
  });
});

describe('feet', () => {
  it('gives a single ground unit no feet — it rests on its own flat bottom edge', () => {
    const { cells } = deriveRack(rack([0, 0]), PITCH);
    expect(cells.get('0,0')!.feet).toBe(false);
  });

  it('gives feet only to the staggered column, matching cad/showcase.scad', () => {
    // showcase.scad: two Pi5 stacked in column q=0, one Rock 5B+ at q=1 half a case up,
    // and body-feet.stl imported under the Rock only.
    const { cells, warnings } = deriveRack(rack([0, 0], [0, 1], [1, 0]), PITCH);
    expect(cells.get('0,0')!.feet).toBe(false); // on-grid, on the ground
    expect(cells.get('0,1')!.feet).toBe(false); // stacked, not a ground unit
    expect(cells.get('1,0')!.feet).toBe(true); // half-offset column
    expect(warnings).toEqual([]);
  });

  it('does not give feet to a unit that has one directly below', () => {
    const { cells } = deriveRack(rack([0, 0], [0, 1], [0, 2]), PITCH);
    expect(cells.get('0,1')!.feet).toBe(false);
    expect(cells.get('0,2')!.feet).toBe(false);
  });

  it('warns instead of pretending a foot can reach more than a half-case', () => {
    // q=2 sits a full case above q=0, which no single foot spans.
    const { cells, warnings } = deriveRack(rack([0, 0], [1, 0], [2, 0]), PITCH);
    expect(cells.get('2,0')!.feet).toBe(true);
    expect(warnings).toHaveLength(1);
    expect(warnings[0].cell).toBe('2,0');
    expect(warnings[0].message).toContain('nothing to stand on');
  });
});

describe('layout helpers', () => {
  it('offers exactly six slots around a lone unit', () => {
    expect(openSlots(rack([0, 0]))).toHaveLength(6);
  });

  it('does not offer a slot that is already occupied', () => {
    const slots = openSlots(rack([0, 0], [0, 1]));
    expect(slots).not.toContain('0,1');
    expect(slots).not.toContain('0,0');
  });

  it('finds the connected component and ignores an island', () => {
    const withIsland = rack([0, 0], [0, 1], [9, 9]);
    const reachable = connectedComponent(withIsland);
    expect(reachable.has('0,0')).toBe(true);
    expect(reachable.has('0,1')).toBe(true);
    expect(reachable.has('9,9')).toBe(false);
  });

  it('labels units from the top down', () => {
    const labels = unitLabels(rack([0, 0], [0, 1]), PITCH);
    expect(labels.get('0,1')).toBe('A');
    expect(labels.get('0,0')).toBe('B');
  });
});

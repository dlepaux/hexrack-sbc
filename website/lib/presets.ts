/**
 * Starting layouts.
 *
 * Every ground unit in a preset must sit at most a half-case above the lowest one, which
 * is exactly how far the foot reaches. A layout that strands a unit higher than that is
 * legal for a user to build — it warns — but a shipped preset should never be the thing
 * that warns. presets.test.ts enforces this.
 */
export interface Preset {
  id: string;
  name: string;
  cells: Array<[number, number]>;
}

export const PRESETS: Preset[] = [
  { id: 'single', name: 'Single', cells: [[0, 0]] },
  {
    id: 'stack2',
    name: 'Stack ×2',
    cells: [
      [0, 0],
      [0, 1],
    ],
  },
  {
    id: 'col3',
    name: 'Column ×3',
    cells: [
      [0, 0],
      [0, 1],
      [0, 2],
    ],
  },
  {
    id: 'pair',
    name: 'Side by side',
    cells: [
      [0, 0],
      [1, 0],
    ],
  },
  {
    id: 'cluster',
    name: 'Cluster ×5',
    cells: [
      [0, 0],
      [0, 1],
      [1, 0],
      [1, 1],
      [-1, 1],
    ],
  },
];

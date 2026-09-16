import { describe, expect, it } from 'vitest';
import fixture from '../fixtures/manifest.json';
import type { Manifest } from '../types/manifest';
import { cellKey, type CellKey, type Unit } from './rack';
import { layoutRack } from './preview';
import { resolveRack, type RackConfig } from './resolve';

const manifest = fixture as unknown as Manifest;
const H = manifest.layout.hex.flatToFlat;

const rack = (...cells: Array<[number, number, Partial<Unit>?]>): Map<CellKey, Unit> =>
  new Map(
    cells.map(([q, r, over]) => [
      cellKey({ q, r }),
      { board: 'rock5b+', antennas: false, labelTop: '', labelBottom: '', ...over },
    ]),
  );

const config = (over: Partial<RackConfig> = {}): RackConfig => ({
  units: rack([0, 0]),
  ventPattern: 'triangles',
  frontCircle: true,
  feetStyle: 'triangle',
  ...over,
});

describe('layoutRack', () => {
  it('shows exactly the files the build sheet would download', () => {
    // The whole point of the preview: it must not show a rack the zip does not contain.
    const c = config({
      units: rack([0, 0], [0, 1], [1, 0, { antennas: true }], [-1, 1, { board: 'rpi5_pironman' }]),
      ventPattern: 'gyroid',
    });
    const placed = new Map<string, number>();
    for (const p of layoutRack(manifest, c).placements) placed.set(p.file, (placed.get(p.file) ?? 0) + 1);

    const sheet = new Map<string, number>();
    for (const p of resolveRack(manifest, c).parts) {
      if (p.source.kind === 'prebuilt') sheet.set(p.source.file, p.quantity);
    }
    expect(placed).toEqual(sheet);
  });

  it('places each section at its CAD offset along the depth', () => {
    const offsets = manifest.layout.byVentPattern.triangles.partOffsetY;
    for (const p of layoutRack(manifest, config()).placements) {
      expect(p.position, p.slot).toEqual([-75, offsets[p.slot], -H / 2]);
    }
  });

  it('follows the selected pattern, whose face depth moves everything behind it', () => {
    const fan = (ventPattern: string) =>
      layoutRack(manifest, config({ ventPattern })).placements.find((p) => p.slot === 'fan')!;
    expect(fan('gyroid').position[1]).toBe(manifest.layout.byVentPattern.gyroid.partOffsetY.fan);
    expect(fan('gyroid').position[1]).toBeGreaterThan(fan('triangles').position[1]);
  });

  it('stands a staggered unit on its foot, and frames the foot too', () => {
    const { placements, bounds } = layoutRack(manifest, config({ units: rack([0, 0], [1, 0]) }));
    const foot = placements.find((p) => p.slot === 'feet')!;
    const face = placements.find((p) => p.cell === '1,0' && p.slot === 'face')!;
    expect(foot.cell).toBe('1,0');
    expect(foot.file).toBe('body-feet.stl');
    expect(foot.position).toEqual(face.position);
    // The foot reaches the floor the on-grid unit stands on.
    expect(bounds.min[2]).toBeCloseTo(-H / 2, 3);
    expect(bounds.max[2]).toBeCloseTo(H, 3);
    expect(bounds.min[0]).toBe(-75);
    expect(bounds.max[0]).toBe(112.5 + 75);
  });

  it('places the pads of a padded foot with it', () => {
    const { placements } = layoutRack(
      manifest,
      config({ units: rack([0, 0], [1, 0]), feetStyle: 'x-pads' }),
    );
    const foot = placements.find((p) => p.slot === 'feet')!;
    const pads = placements.find((p) => p.slot === 'feet-pad')!;
    expect(pads.file).toBe('body-feet-pad.stl');
    expect(pads.position).toEqual(foot.position);
  });

  it('keys meshes by unit and slot, so swapping a variant keeps the key', () => {
    const before = layoutRack(manifest, config({ units: rack([0, 0]) }));
    const after = layoutRack(manifest, config({ units: rack([0, 0], [0, 1]) }));
    const top = (l: typeof before) => l.placements.find((p) => p.cell === '0,0' && p.slot === 'back-top')!;
    expect(top(before).key).toBe(top(after).key);
    expect(top(before).file).not.toBe(top(after).file);
  });
});

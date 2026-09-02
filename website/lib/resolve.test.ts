import { describe, expect, it } from 'vitest';
import fixture from '../fixtures/manifest.json';
import type { Manifest } from '../types/manifest';
import { DIRECTIONS, cellKey, type CellKey, type Unit } from './rack';
import { backFaceVent, resolveRack, type RackConfig } from './resolve';

// Resolved against the manifest the build actually emits, not a hand-written stub — a
// stub would pass while the real naming scheme drifted underneath it.
const manifest = fixture as unknown as Manifest;

const rack = (...cells: Array<[number, number, Partial<Unit>?]>): Map<CellKey, Unit> =>
  new Map(
    cells.map(([q, r, over]) => [
      cellKey({ q, r }),
      { board: 'rock5b+', antennas: false, ...over },
    ]),
  );

const config = (over: Partial<RackConfig> = {}): RackConfig => ({
  units: rack([0, 0]),
  ventPattern: 'triangles',
  frontCircle: true,
  ...over,
});

const fileFor = (r: ReturnType<typeof resolveRack>, part: string) =>
  r.parts.find((p) => p.part === part)?.file;

describe('the fixture is a valid v2 manifest', () => {
  it('declares the schema version the resolver expects', () => {
    expect(manifest.schemaVersion).toBe(2);
  });

  it('carries machine-readable options on every part', () => {
    for (const p of manifest.parts) {
      expect(p.options, p.file).toBeDefined();
      expect(p.bytes, p.file).toBeGreaterThan(0);
      expect(p.triangles, p.file).toBeGreaterThan(0);
    }
  });
});

describe('resolving a single unit', () => {
  it('produces the six parts a lone unit needs, and no feet', () => {
    const r = resolveRack(manifest, config());
    expect(r.missing).toEqual([]);
    expect(r.unitCount).toBe(1);
    expect(r.totalParts).toBe(6);
    expect(r.parts.map((p) => p.part).sort()).toEqual([
      'back-bottom',
      'back-face',
      'back-top',
      'dust',
      'face',
      'fan',
    ]);
  });

  it('takes the un-suffixed filenames for the default configuration', () => {
    const r = resolveRack(manifest, config());
    expect(fileFor(r, 'face')).toBe('body-face.stl');
    expect(fileFor(r, 'dust')).toBe('body-dust.stl');
    // A lone unit has no neighbours, so both dovetail sets are empty -> the "none" variant.
    expect(fileFor(r, 'back-top')).toBe('body-back-top-none.stl');
    expect(fileFor(r, 'back-bottom')).toBe('body-back-bottom-rock5b+-none.stl');
  });

  it('switches the face file with the vent pattern and the front circle', () => {
    expect(fileFor(resolveRack(manifest, config({ ventPattern: 'voronoi' })), 'face')).toBe(
      'body-face-voronoi.stl',
    );
    expect(fileFor(resolveRack(manifest, config({ frontCircle: false })), 'face')).toBe(
      'body-face-nocircle.stl',
    );
    expect(
      fileFor(resolveRack(manifest, config({ ventPattern: 'grid', frontCircle: false })), 'face'),
    ).toBe('body-face-grid-nocircle.stl');
  });

  it('switches the back panel with the board and the antennas', () => {
    const pironman = resolveRack(manifest, config({ units: rack([0, 0, { board: 'rpi5_pironman' }]) }));
    expect(fileFor(pironman, 'back-bottom')).toContain('rpi5_pironman');

    const withAntennas = resolveRack(manifest, config({ units: rack([0, 0, { antennas: true }]) }));
    expect(fileFor(withAntennas, 'back-face')).toContain('-antennas');
  });
});

describe('the back face vent fallback', () => {
  it('passes a supported pattern straight through', () => {
    expect(backFaceVent(manifest, 'grid')).toBe('grid');
  });

  it('substitutes triangles for a pattern the 3mm back face cannot carry', () => {
    // gyroid is not in the build axis yet, but the fallback must already be honoured so
    // the day it ships, the back panel resolves instead of 404ing.
    expect(backFaceVent(manifest, 'gyroid')).toBe('triangles');
  });

  it('resolves the back face through the fallback, not the raw choice', () => {
    const r = resolveRack(manifest, config({ ventPattern: 'gyroid' }));
    const backFace = r.parts.find((p) => p.part === 'back-face');
    expect(backFace?.file).toBe('body-back-face-rock5b+-none.stl');
  });
});

describe('resolving a rack', () => {
  it('derives paired dovetail files for a vertical stack', () => {
    const r = resolveRack(manifest, config({ units: rack([0, 0], [0, 1]) }));
    expect(r.missing).toEqual([]);
    expect(r.unitCount).toBe(2);
    // Lower unit presents a rail upward; upper unit receives it.
    const files = r.parts.map((p) => p.file);
    expect(files).toContain('body-back-top-t.stl');
    expect(files).toContain('body-back-bottom-rock5b+-b.stl');
    expect(files).toContain('body-back-face-rock5b+-b.stl');
  });

  it('gives Back Bottom and Back Face the same dovetail code, which is the print-pairing rule', () => {
    const r = resolveRack(manifest, config({ units: rack([0, 0], [0, 1], [1, 0]) }));
    const suffix = (f?: string) => f?.replace(/^body-back-(bottom|face)-rock5b\+/, '');
    const bottoms = r.parts.filter((p) => p.part === 'back-bottom').map((p) => suffix(p.file));
    const faces = r.parts.filter((p) => p.part === 'back-face').map((p) => suffix(p.file));
    expect(new Set(bottoms)).toEqual(new Set(faces));
  });

  it('aggregates identical parts instead of listing them per unit', () => {
    const r = resolveRack(manifest, config({ units: rack([0, 0], [0, 1], [0, 2]) }));
    const dust = r.parts.find((p) => p.part === 'dust');
    expect(dust?.quantity).toBe(3);
    // Three units, but only one dust row.
    expect(r.parts.filter((p) => p.part === 'dust')).toHaveLength(1);
  });

  it('adds feet only for the staggered column', () => {
    const r = resolveRack(manifest, config({ units: rack([0, 0], [0, 1], [1, 0]) }));
    const feet = r.parts.find((p) => p.part === 'feet');
    expect(feet?.quantity).toBe(1);
  });

  it('resolves every part of a fully surrounded unit', () => {
    const r = resolveRack(
      manifest,
      config({ units: rack([0, 0], [0, 1], [1, 0], [-1, 1], [0, -1], [-1, 0], [1, -1]) }),
    );
    expect(r.missing).toEqual([]);
    expect(r.unitCount).toBe(7);
  });

  it('sums bytes across quantities so the download figure is honest', () => {
    const one = resolveRack(manifest, config());
    const three = resolveRack(manifest, config({ units: rack([0, 0], [0, 1], [0, 2]) }));
    expect(three.totalBytes).toBeGreaterThan(one.totalBytes);
    const dust = three.parts.find((p) => p.part === 'dust')!;
    expect(dust.quantity).toBe(3);
  });
});

describe('hardware', () => {
  it('scales the fastener counts with the number of units', () => {
    const one = resolveRack(manifest, config());
    const two = resolveRack(manifest, config({ units: rack([0, 0], [0, 1]) }));
    const fan = (r: ReturnType<typeof resolveRack>) =>
      r.hardware.find((h) => h.name.includes('Noctua NF-A9'))!.quantity;
    expect(fan(one)).toBe(1);
    expect(fan(two)).toBe(2);
  });

  it('does not list antenna hardware unless a unit has antennas', () => {
    const plain = resolveRack(manifest, config());
    expect(plain.hardware.some((h) => h.name.includes('SMA'))).toBe(false);

    const withAntennas = resolveRack(manifest, config({ units: rack([0, 0, { antennas: true }]) }));
    expect(withAntennas.hardware.find((h) => h.name.includes('SMA'))?.quantity).toBe(2);
  });

  it('never offers M3-16, which the CAD does not use', () => {
    const r = resolveRack(manifest, config());
    expect(r.hardware.some((h) => h.name.includes('M3×16'))).toBe(false);
    expect(r.hardware.some((h) => h.name.includes('M4×50'))).toBe(true);
  });
});

describe('every reachable configuration resolves', () => {
  // The build-time completeness check covers the manifest; this covers the resolver that
  // reads it. Between them, no combination the UI can express can 404.
  it('resolves all board x pattern x circle x antenna combinations for a lone unit', () => {
    for (const board of manifest.axes.board.values) {
      for (const ventPattern of manifest.axes.ventPattern.values) {
        for (const frontCircle of manifest.axes.frontCircle.values) {
          for (const antennas of manifest.axes.antennas.values) {
            const r = resolveRack(
              manifest,
              config({ units: rack([0, 0, { board, antennas }]), ventPattern, frontCircle }),
            );
            expect(r.missing, `${board}/${ventPattern}/${frontCircle}/${antennas}`).toEqual([]);
          }
        }
      }
    }
  });

  it('resolves every dovetail subset a neighbour can produce', () => {
    for (const d of DIRECTIONS) {
      const r = resolveRack(manifest, config({ units: rack([0, 0], [d.dq, d.dr]) }));
      expect(r.missing, `neighbour ${d.face}`).toEqual([]);
    }
  });
});

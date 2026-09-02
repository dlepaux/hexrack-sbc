import { describe, expect, it } from 'vitest';
import { PRESETS } from './presets';
import fixture from '../fixtures/manifest.json';
import type { Manifest } from '../types/manifest';
import { cellKey, connectedComponent, deriveRack, type CellKey, type Unit } from './rack';
import { resolveRack } from './resolve';

const manifest = fixture as unknown as Manifest;
const PITCH = { column: 112.5, row: 129.903810567666 };

const toUnits = (cells: Array<[number, number]>): Map<CellKey, Unit> =>
  new Map(cells.map(([q, r]) => [cellKey({ q, r }), { board: 'rock5b+', antennas: false }]));

describe('shipped presets', () => {
  // A preset is the first thing a visitor sees. If one of them warns, the warning reads
  // as a bug in the site rather than as feedback about a layout the user built.
  it.each(PRESETS.map((p) => [p.name, p] as const))(
    '%s produces a buildable layout with no warnings',
    (_name, preset) => {
      const units = toUnits(preset.cells);
      const { warnings } = deriveRack(units, PITCH);
      expect(warnings).toEqual([]);
    },
  );

  it.each(PRESETS.map((p) => [p.name, p] as const))('%s is a single connected rack', (_name, preset) => {
    const units = toUnits(preset.cells);
    expect(connectedComponent(units).size).toBe(units.size);
  });

  it.each(PRESETS.map((p) => [p.name, p] as const))('%s resolves every part', (_name, preset) => {
    const rack = resolveRack(manifest, {
      units: toUnits(preset.cells),
      ventPattern: manifest.axes.ventPattern.default,
      frontCircle: true,
    });
    expect(rack.missing).toEqual([]);
    expect(rack.parts.length).toBeGreaterThan(0);
  });

  it('has no duplicate cells within a preset', () => {
    for (const preset of PRESETS) {
      const keys = preset.cells.map(([q, r]) => cellKey({ q, r }));
      expect(new Set(keys).size, preset.name).toBe(keys.length);
    }
  });
});

/**
 * Configuration → the exact files to print.
 *
 * Every lookup compares `parts[].options` against the configuration. Nothing here parses
 * a filename or reads the human `variant` string, so renaming a variant cannot break a
 * download and adding a build axis cannot silently resolve to the wrong part.
 *
 * scripts/test-manifest.sh walks the same cross-product at build time and fails CI if any
 * reachable combination does not resolve to exactly one part.
 */

import type { Face, Manifest, Part, PartSlot } from '../types/manifest';
import { type CellKey, type Unit, deriveRack, type RackWarning } from './rack';

export interface RackConfig {
  units: ReadonlyMap<CellKey, Unit>;
  ventPattern: string;
  frontCircle: boolean;
}

export interface ResolvedPart {
  part: PartSlot;
  name: string;
  file: string;
  bytes: number;
  triangles: number;
  quantity: number;
  /** Short human note for the build sheet, e.g. "rails top · top-right". */
  note?: string;
}

export interface ResolvedRack {
  parts: ResolvedPart[];
  warnings: RackWarning[];
  /** Combinations the build did not produce. Empty unless the manifest is broken. */
  missing: string[];
  totalBytes: number;
  totalParts: number;
  unitCount: number;
  hardware: Array<{ name: string; quantity: number }>;
}

const sameSet = (a: readonly string[] = [], b: readonly string[] = []): boolean =>
  a.length === b.length && [...a].sort().join('|') === [...b].sort().join('|');

/**
 * The pattern the back panel actually carries. The 3mm back face cannot hold every
 * pattern the 2mm front can, and the substitution lives in the manifest so this stays a
 * lookup rather than a rule reimplemented on both sides of the build.
 */
export function backFaceVent(manifest: Manifest, pattern: string): string {
  return manifest.axes.ventPattern.backFaceFallback[pattern] ?? pattern;
}

function findPart(
  manifest: Manifest,
  slot: PartSlot,
  match: (p: Part) => boolean,
): Part | undefined {
  return manifest.parts.find((p) => p.part === slot && match(p));
}

const faceList = (faces: readonly Face[]): string =>
  faces.length === 0 ? 'none' : faces.join(' · ');

export function resolveRack(manifest: Manifest, config: RackConfig): ResolvedRack {
  const pitch = { column: manifest.layout.gridPitch.column, row: manifest.layout.gridPitch.row };
  const { cells, warnings } = deriveRack(config.units, pitch);
  const bfVent = backFaceVent(manifest, config.ventPattern);

  // Aggregated by file: a rack of six units mostly reuses the same handful of parts,
  // and the user wants "print this one ×6", not six identical rows.
  const agg = new Map<string, ResolvedPart>();
  const missing: string[] = [];

  const add = (found: Part | undefined, describe: string, note?: string) => {
    if (!found) {
      missing.push(describe);
      return;
    }
    const existing = agg.get(found.file);
    if (existing) {
      existing.quantity += 1;
      return;
    }
    agg.set(found.file, {
      part: found.part,
      name: found.name,
      file: found.file,
      bytes: found.bytes,
      triangles: found.triangles,
      quantity: 1,
      note,
    });
  };

  for (const [key, unit] of config.units) {
    const d = cells.get(key);
    if (!d) continue;

    add(
      findPart(
        manifest,
        'face',
        (p) =>
          p.options.ventPattern === config.ventPattern &&
          p.options.frontCircle === config.frontCircle,
      ),
      `face ${config.ventPattern} circle=${config.frontCircle}`,
    );
    add(findPart(manifest, 'dust', () => true), 'dust');
    add(findPart(manifest, 'fan', () => true), 'fan');

    add(
      findPart(manifest, 'back-top', (p) => sameSet(p.options.dovetails, d.male)),
      `back-top ${faceList(d.male)}`,
      `rails ${faceList(d.male)}`,
    );
    add(
      findPart(
        manifest,
        'back-bottom',
        (p) => p.options.board === unit.board && sameSet(p.options.dovetails, d.female),
      ),
      `back-bottom ${unit.board} ${faceList(d.female)}`,
      `grooves ${faceList(d.female)}`,
    );
    add(
      findPart(
        manifest,
        'back-face',
        (p) =>
          p.options.board === unit.board &&
          p.options.antennas === unit.antennas &&
          p.options.ventPattern === bfVent &&
          sameSet(p.options.dovetails, d.female),
      ),
      `back-face ${unit.board} ant=${unit.antennas} vent=${bfVent} ${faceList(d.female)}`,
      `grooves ${faceList(d.female)}`,
    );

    if (d.feet) add(findPart(manifest, 'feet', () => true), 'feet', 'bridges the half-column offset');
  }

  const parts = [...agg.values()];
  const unitCount = config.units.size;
  const antennaUnits = [...config.units.values()].filter((u) => u.antennas).length;

  const hardware = manifest.hardware
    .map((h) => ({
      name: h.name,
      quantity: h.perUnit * unitCount + (h.perAntennaUnit ?? 0) * antennaUnits,
    }))
    .filter((h) => h.quantity > 0);

  return {
    parts,
    warnings,
    missing,
    totalBytes: parts.reduce((n, p) => n + p.bytes * p.quantity, 0),
    totalParts: parts.reduce((n, p) => n + p.quantity, 0),
    unitCount,
    hardware,
  };
}

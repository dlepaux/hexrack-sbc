/**
 * Configuration → the exact files to print.
 *
 * Every lookup compares `parts[].options` against the configuration. Nothing here parses
 * a filename or reads the human `variant` string, so renaming a variant cannot break a
 * download and adding a build axis cannot silently resolve to the wrong part.
 *
 * scripts/test-manifest.sh walks the same cross-product at build time and fails CI if any
 * reachable combination does not resolve to exactly one part.
 *
 * ENGRAVING is the one thing the build cannot pre-produce: a label is per-unit, so the
 * dust filter's mesh depends on text only the visitor knows. Such a part resolves to an
 * `engraved` source carrying the label rather than to a published file, and its size is
 * deliberately absent -- see PartSource.
 */

import type { Face, Manifest, Part, PartSlot } from '../types/manifest';
import { engravedLabel } from './labels';
import { type CellKey, type Unit, deriveRack, type RackWarning, unitLabels } from './rack';

export interface RackConfig {
  units: ReadonlyMap<CellKey, Unit>;
  ventPattern: string;
  frontCircle: boolean;
}

/**
 * Where a part's bytes come from -- and, for an engraved part, the fact that they do not
 * exist yet.
 *
 * The manifest's `bytes`/`triangles` are measured from the artifact CI produced. Engrave a
 * label and that mesh changes completely (96 to 1414 facets, 4884 to 70784 bytes, and it
 * varies with the text), so reusing the manifest figure would make the download button
 * understate the size by an order of magnitude. Splitting the union is what makes the
 * absent number impossible to read by accident.
 */
export type PartSource =
  | { kind: 'prebuilt'; file: string; bytes: number; triangles: number }
  | {
      kind: 'engraved';
      /** Zip entry and slicer filename. Unique by construction -- see entryName. */
      entry: string;
      labelTop: string;
      labelBottom: string;
      /** Facet count of the unlabelled part, so the worker can prove the engraving happened. */
      blankTriangles: number;
    };

export interface ResolvedPart {
  /**
   * Identity. Two dust filters differing only by label are different parts, so the file
   * name alone will not do -- this keys the React rows and the generated-mesh cache.
   */
  key: string;
  part: PartSlot;
  name: string;
  quantity: number;
  source: PartSource;
  /** Short human note for the build sheet, e.g. "rails top · top-right". */
  note?: string;
}

export interface ResolvedRack {
  parts: ResolvedPart[];
  warnings: RackWarning[];
  /** Combinations the build did not produce. Empty unless the manifest is broken. */
  missing: string[];
  /**
   * Bytes of the PREBUILT parts only, named so no caller can mistake it for the download
   * total. There is deliberately no `totalBytes`: a rack containing an engraved part has
   * no knowable total until the browser has cut it.
   */
  prebuiltBytes: number;
  /** Parts whose mesh -- and therefore size -- the browser still has to produce. */
  engravedCount: number;
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

/** A label reduced to a filename fragment. Lossy on purpose; uniqueness comes from elsewhere. */
const slug = (s: string): string =>
  s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

/**
 * The filename an engraved part is downloaded and zipped under.
 *
 * Unique BY CONSTRUCTION, not by sanitising the label: JSZip silently overwrites a
 * colliding entry, so two labels that slug to the same string would ship one filter twice
 * and the other never. The unit letters are what guarantee it -- they partition the rack,
 * so no two groups can share them. The slug is only there to make the file recognisable,
 * and a label with no ASCII in it simply contributes nothing.
 */
export function entryName(
  labelTop: string,
  labelBottom: string,
  letters: readonly string[],
): string {
  const text = slug([labelTop, labelBottom].filter(Boolean).join(' '));
  return ['body-dust', text, letters.join('')].filter(Boolean).join('-') + '.stl';
}

/** Groups the units that print the identical part, so the sheet says "x3" rather than listing three. */
interface Aggregated {
  found: Part;
  part: PartSlot;
  name: string;
  note?: string;
  quantity: number;
  labelTop: string;
  labelBottom: string;
  /** Unit letters sharing this part, in the order the grid labels them. */
  letters: string[];
}

export function resolveRack(manifest: Manifest, config: RackConfig): ResolvedRack {
  const pitch = { column: manifest.layout.gridPitch.column, row: manifest.layout.gridPitch.row };
  const { cells, warnings } = deriveRack(config.units, pitch);
  const bfVent = backFaceVent(manifest, config.ventPattern);
  const letters = unitLabels(config.units, pitch);

  // Aggregated by file AND label: a rack of six units mostly reuses the same handful of
  // parts, and the user wants "print this one x6" rather than six identical rows -- but two
  // filters engraved differently are genuinely two parts. For every part that carries no
  // label the key ends in two empty fields, so the grouping is exactly what it always was.
  const agg = new Map<string, Aggregated>();
  const missing: string[] = [];

  const add = (
    found: Part | undefined,
    describe: string,
    opts: { note?: string; cell?: CellKey; labelTop?: string; labelBottom?: string } = {},
  ) => {
    if (!found) {
      missing.push(describe);
      return;
    }
    const labelTop = engravedLabel(opts.labelTop ?? '');
    const labelBottom = engravedLabel(opts.labelBottom ?? '');
    const key = `${found.file} ${labelTop} ${labelBottom}`;
    const letter = opts.cell ? letters.get(opts.cell) : undefined;

    const existing = agg.get(key);
    if (existing) {
      existing.quantity += 1;
      if (letter) existing.letters.push(letter);
      return;
    }
    agg.set(key, {
      found,
      part: found.part,
      name: found.name,
      note: opts.note,
      quantity: 1,
      labelTop,
      labelBottom,
      letters: letter ? [letter] : [],
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
    add(findPart(manifest, 'dust', () => true), 'dust', {
      cell: key,
      labelTop: unit.labelTop,
      labelBottom: unit.labelBottom,
    });
    add(findPart(manifest, 'fan', () => true), 'fan');

    add(
      findPart(manifest, 'back-top', (p) => sameSet(p.options.dovetails, d.male)),
      `back-top ${faceList(d.male)}`,
      { note: `rails ${faceList(d.male)}` },
    );
    add(
      findPart(
        manifest,
        'back-bottom',
        (p) => p.options.board === unit.board && sameSet(p.options.dovetails, d.female),
      ),
      `back-bottom ${unit.board} ${faceList(d.female)}`,
      { note: `grooves ${faceList(d.female)}` },
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
      { note: `grooves ${faceList(d.female)}` },
    );

    if (d.feet)
      add(findPart(manifest, 'feet', () => true), 'feet', {
        note: 'bridges the half-column offset',
      });
  }

  const parts: ResolvedPart[] = [...agg.entries()].map(([key, a]) => ({
    key,
    part: a.part,
    name: a.name,
    quantity: a.quantity,
    note: a.note,
    source:
      a.labelTop === '' && a.labelBottom === ''
        ? {
            kind: 'prebuilt',
            file: a.found.file,
            bytes: a.found.bytes,
            triangles: a.found.triangles,
          }
        : {
            kind: 'engraved',
            entry: entryName(a.labelTop, a.labelBottom, a.letters),
            labelTop: a.labelTop,
            labelBottom: a.labelBottom,
            blankTriangles: a.found.triangles,
          },
  }));

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
    prebuiltBytes: parts.reduce(
      (n, p) => n + (p.source.kind === 'prebuilt' ? p.source.bytes * p.quantity : 0),
      0,
    ),
    engravedCount: parts.filter((p) => p.source.kind === 'engraved').length,
    totalParts: parts.reduce((n, p) => n + p.quantity, 0),
    unitCount,
    hardware,
  };
}

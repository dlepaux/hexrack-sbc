/**
 * Manifest v2 — the only interface between the CI build and the configurator.
 *
 * The configurator builds its controls from `axes` and resolves parts by comparing
 * `parts[].options`. It never parses a filename and never hardcodes an enum, so a
 * pattern that stops being built simply stops being offered, and one that starts
 * being built appears with no frontend change.
 *
 * Emitted by scripts/generate-stl.sh; the cross-product is checked by
 * scripts/test-manifest.sh, which fails the build if any reachable combination
 * does not resolve to exactly one part.
 */

export const SCHEMA_VERSION = 2;

export type Board = string;
export type VentPattern = string;

/** The three faces a case presents upward. Rails (male) are unioned onto Back Top. */
export type MaleFace = 'top' | 'top-right' | 'top-left';
/** The three it presents downward. Grooves (female) are cut into Back Bottom AND Back Face. */
export type FemaleFace = 'bottom' | 'bottom-left' | 'bottom-right';
export type Face = MaleFace | FemaleFace;

/** The seven printed parts of one case. */
export type PartSlot =
  | 'dust' | 'face' | 'fan' | 'feet'
  | 'back-top' | 'back-bottom' | 'back-face';

export interface PartOptions {
  board?: Board;
  ventPattern?: VentPattern;
  frontCircle?: boolean;
  antennas?: boolean;
  dovetails?: Face[];
}

export interface Part {
  id: string;
  /** Stable slot this part fills. The resolver keys off this, not off `id` or `file`. */
  part: PartSlot;
  name: string;
  file: string;
  options: PartOptions;
  bytes: number;
  triangles: number;
  /** Human label, for the gallery only. Never parsed. */
  variant?: string;
  excludeFromDownloadAll?: boolean;
}

export interface Axes {
  board: { values: Board[]; labels: Record<string, string> };
  ventPattern: {
    values: VentPattern[];
    default: VentPattern;
    /**
     * Patterns the 3mm back face cannot carry, and what it uses instead. The back panel
     * follows the face's pattern except where this says otherwise — the client must apply
     * it rather than reimplement the rule.
     */
    backFaceFallback: Record<string, VentPattern>;
  };
  frontCircle: { values: boolean[]; default?: boolean };
  antennas: { values: boolean[]; default?: boolean };
  faces: { male: MaleFace[]; female: FemaleFace[]; mates: Record<Face, Face> };
}

export interface Layout {
  units: string;
  hex: { pointToPoint: number; flatToFlat: number; orientation: string };
  gridPitch: { column: number; row: number; columnStagger: number };
  caseDepth: number;
  /** Section placement along Y, from cad/body.scad at bodyAssembly_space = 0. */
  partOffsetY: Record<PartSlot, number>;
  feet: { drop: number; rule: string };
}

export interface Fastener {
  id: string;
  name: string;
  perUnit: number;
  perAntennaUnit?: number;
}

export interface PartGroup {
  id: string;
  name: string;
  description: string;
  parts: Part[];
}

export interface Assemblies {
  body: string;
}

export interface Manifest {
  schemaVersion: number;
  generated: string;
  commit: string;
  assemblies?: Assemblies;
  axes: Axes;
  layout: Layout;
  hardware: Fastener[];
  parts: Part[];
  /** Retained so the full gallery keeps working alongside the configurator. */
  groups: PartGroup[];
}

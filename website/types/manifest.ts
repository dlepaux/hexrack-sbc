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

// v3 added the required `labelLimit`. Required rather than optional on purpose: an absent
// limit would let the configurator ship an unbounded label input, and an overlong label is
// the one failure mode that renders exit-0 with its glyphs quietly chipped off.
export const SCHEMA_VERSION = 3;

export type Board = string;
export type VentPattern = string;

/** The three faces a case presents upward. Rails (male) are unioned onto Back Top. */
export type MaleFace = 'top' | 'top-right' | 'top-left';
/** The three it presents downward. Grooves (female) are cut into Back Bottom AND Back Face. */
export type FemaleFace = 'bottom' | 'bottom-left' | 'bottom-right';
export type Face = MaleFace | FemaleFace;

/**
 * The printed parts of one case.
 *
 * `back-fan` is the only OPTIONAL one: it holds the rear pull fan and exists solely for
 * boards that have one, so a resolver must not treat its absence as a missing part. Every
 * other slot is present for every board.
 */
export type PartSlot =
  | 'dust' | 'face' | 'fan' | 'feet'
  | 'back-top' | 'back-bottom' | 'back-fan' | 'back-face';

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

/**
 * The part of the layout that moves with the face panel's depth, for one board.
 *
 * face_depth is derived from the SELECTED pattern's panel thickness, so the gyroid's 11mm
 * panel gives a 164.3mm case where the flat patterns give a 155.3mm one, and everything
 * behind the face shifts with it. caseDepth and the back-face offset additionally depend
 * on the board — see Layout.byBoard.
 */
export interface VentPatternLayout {
  caseDepth: number;
  /**
   * Section placement along Y, from cad/body.scad at bodyAssembly_space = 0.
   *
   * Partial because `back-fan` only exists for boards with a rear pull fan — and on those
   * boards it also pushes `back-face` out by its own depth, so the two move together.
   */
  partOffsetY: Partial<Record<PartSlot, number>>;
}

export interface BoardLayout {
  byVentPattern: Record<VentPattern, VentPatternLayout>;
}

export interface Layout {
  units: string;
  hex: { pointToPoint: number; flatToFlat: number; orientation: string };
  gridPitch: { column: number; row: number; columnStagger: number };
  /**
   * Keyed by board, then by vent pattern. There is deliberately no top-level
   * caseDepth/partOffsetY fallback and neither axis is collapsed: a default is precisely
   * what would go unnoticed while being wrong for the case that differs.
   *
   * Both axes are real. The vent pattern moves everything behind the face, because
   * face_depth follows the selected panel's thickness. The board moves the back, because
   * back_depth is 160 for `bitaxe_naja_duo` and 115 for the rest — that board is 147mm
   * long and can only lie front-to-back. So a rack can legitimately mix two case lengths,
   * and each unit must be read as `byBoard[unit.board].byVentPattern[config.ventPattern]`.
   */
  byBoard: Record<string, BoardLayout>;
  feet: { drop: number; rule: string };
}

/**
 * The bound on an engraved label, derived by the CAD and harvested at build time.
 *
 * Never re-derived in TypeScript: the derivation needs sectionDust()'s inner-wall literal,
 * and a second copy of that number is exactly the drift cad/layout-export.scad exists to
 * prevent. dustLabelCutter() echoes it, scripts/generate-stl.sh reads the echo, and the
 * build fails if it is missing.
 */
export interface LabelLimit {
  /** Usable flat of the hexagon band, in mm. A label wider than this loses its outer glyphs. */
  safeWidthMm: number;
  /** The CAD's dust_label_size. The browser needs it to reproduce OpenSCAD's text metrics. */
  sizeMm: number;
  /** Fontconfig pattern the CAD engraves with; public/fonts carries the matching TTF. */
  font: string;
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
  labelLimit: LabelLimit;
  hardware: Fastener[];
  parts: Part[];
  /** Retained so the full gallery keeps working alongside the configurator. */
  groups: PartGroup[];
}

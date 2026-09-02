/**
 * The engraved dust-filter label: what a user may type, and whether it fits.
 *
 * Two hazards meet in this one string, and both are load-bearing.
 *
 * INJECTION. The label reaches OpenSCAD spliced into `-D dust_label_top="..."`. A label
 * carrying a quote closes that argument and everything after it is executed as OpenSCAD --
 * verified, not theoretical. The allowed set below has no `"` and no `\`, so the splice
 * cannot be escaped. This is a trust boundary, so it is enforced here and applied at every
 * entry point (the input, the shared-link decoder, the worker), never at the call site.
 *
 * WIDTH. An overlong label does not fail. It renders exit-0 as a valid manifold with its
 * outer glyphs chipped off, because glyphs running past the hexagon's flat remove LESS
 * material rather than more. cad/sections/body/dust.scad asserts against this and publishes
 * the real bound as manifest.labelLimit; measureLabelMm reproduces OpenSCAD's textmetrics
 * in the browser so the field can refuse the label before a 3MB download and a 2s render.
 */

/** Long enough for "NODE-01-RACK-A" and short enough that the width gate is rarely the thing that stops you. */
export const LABEL_MAX_CHARS = 24;

/**
 * Printable ASCII minus the shell- and path-hostile characters.
 *
 * No `"` or `\` (the -D splice), no `/` or `%` (zip entry names), no non-Latin1 (btoa, which
 * encodes the shared link, throws outside it). Narrow on purpose: the width measurement's
 * error bounds were established over printable ASCII, and kerning behaves differently
 * outside it.
 */
const ALLOWED = /[^A-Za-z0-9 ._#+()-]/g;

/**
 * What the input box accepts. Interior and trailing spaces survive, so "NODE " can still
 * grow into "NODE 01" while the user types.
 */
export const sanitiseLabel = (raw: string): string =>
  raw.replace(ALLOWED, '').slice(0, LABEL_MAX_CHARS);

/**
 * What actually gets cut into the plastic, and therefore what identifies the part.
 *
 * Trimmed, because OpenSCAD does not treat "   " as empty -- it engraves three spaces,
 * producing a mesh that differs from the blank filter while looking identical. That would
 * silently turn an unlabelled part into a generated one.
 */
export const engravedLabel = (raw: string): string => sanitiseLabel(raw).trim();

/**
 * Slack between the measured width and the CAD's bound.
 *
 * The browser measurement tracks OpenSCAD's textmetrics to within 0.005mm in Chrome; this
 * is 100x that, to absorb hinting differences in browsers that have not been measured. It
 * costs about a fifth of one capital letter.
 */
export const LABEL_WIDTH_MARGIN_MM = 0.5;

/**
 * `null` means the width could not be measured -- the font had not loaded, or there is no
 * DOM. That is not a rejection: the CAD assert is the authority and still fires in the
 * worker. Gating on an unmeasured label would refuse valid text.
 */
export const labelIsTooWide = (widthMm: number | null, safeWidthMm: number): boolean =>
  widthMm !== null && widthMm > safeWidthMm - LABEL_WIDTH_MARGIN_MM;

/** Nothing to engrave, so nothing to generate -- the published body-dust.stl is correct as-is. */
export const isBlank = (top: string, bottom: string): boolean =>
  engravedLabel(top) === '' && engravedLabel(bottom) === '';

// --- measurement --------------------------------------------------------------------

/**
 * OpenSCAD's text(size=) is an em size in points at 100 dpi, so one unit of `size` is
 * 100/72 mm. Not cap height, despite what the parameter looks like.
 */
const MM_PER_SIZE_UNIT = 100 / 72;

/** Measured large and scaled down; the ratio is scale-invariant but the rounding is not. */
const MEASURE_PX = 500;
const FONT_FAMILY = 'HexrackLabel';

let fontReady: Promise<boolean> | null = null;

/**
 * Loads the same TTF the worker mounts into OpenSCAD. Measuring one font while engraving
 * another would make the gate a lie, which is why the file is committed rather than taken
 * from whatever the system happens to call "Liberation Sans".
 */
function loadFont(url: string): Promise<boolean> {
  fontReady ??= (async () => {
    if (typeof document === 'undefined' || typeof FontFace === 'undefined') return false;
    try {
      const face = new FontFace(FONT_FAMILY, `url(${url})`);
      await face.load();
      document.fonts.add(face);
      // A FontFace that failed to land leaves measureText silently measuring a fallback.
      return document.fonts.check(`${MEASURE_PX}px ${FONT_FAMILY}`);
    } catch {
      return false;
    }
  })();
  return fontReady;
}

/**
 * The label's ink width in millimetres, or `null` if it could not be measured.
 *
 * Ink width, not advance width: OpenSCAD's textmetrics().size[0] is the inked extent, and
 * the advance overstates it by the right side bearing.
 */
export async function measureLabelMm(
  text: string,
  sizeMm: number,
  fontUrl: string,
): Promise<number | null> {
  if (text === '') return 0;
  if (!(await loadFont(fontUrl))) return null;

  const ctx = document.createElement('canvas').getContext('2d');
  if (!ctx) return null;

  ctx.font = `${MEASURE_PX}px ${FONT_FAMILY}`;
  const m = ctx.measureText(text);
  const mmPerPx = (sizeMm * MM_PER_SIZE_UNIT) / MEASURE_PX;
  return (m.actualBoundingBoxLeft + m.actualBoundingBoxRight) * mmPerPx;
}

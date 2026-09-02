/**
 * The CAD sources the browser hands to OpenSCAD.
 *
 * Globbed, not listed: a hand-maintained file list is a trap that breaks silently the day
 * dust.scad grows an include, because OpenSCAD only WARNS about a missing library and goes
 * on to export a valid-looking part.
 *
 * SBC_Model_Framework is excluded and stubbed. It is 1.23MB -- 87% of cad/'s source bytes
 * -- of board models that body.scad and dust.scad `use`, but that body_part="dust" never
 * instantiates; dropping it leaves the mesh byte-identical while cutting the parse from
 * ~0.6s to ~0.11s. It is NOT dead weight for other parts (deleting it silently changes
 * back-bottom and back-face), so this prune is only sound because the browser renders
 * exactly one part. Zero-byte stubs stand in for the two files that are `use`d and
 * `include`d by name, so the render stays warning-free rather than merely working.
 *
 * scripts/test-dust-label.sh renders the real tree and this pruned one and compares the
 * bytes. That test, not this comment, is what keeps the prune honest.
 */

const globbed = import.meta.glob<string>(
  ['../../cad/**/*.scad', '../../cad/**/*.cfg', '!../../cad/SBC_Model_Framework/**'],
  { query: '?raw', import: 'default', eager: true },
);

const PREFIX = '../../cad/';

export const cadSources: Readonly<Record<string, string>> = {
  ...Object.fromEntries(
    Object.entries(globbed).map(([path, text]) => [path.slice(PREFIX.length), text]),
  ),
  'SBC_Model_Framework/sbc_models.scad': '',
  'SBC_Model_Framework/sbc_models.cfg': '',
};

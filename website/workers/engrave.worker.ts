/// <reference lib="webworker" />
/**
 * Engraves a dust filter, using the real OpenSCAD compiled to WebAssembly.
 *
 * The mesh comes out of the same Manifold engine and the same cad/ sources as every
 * published STL, which is the whole reason for carrying a 3MB runtime: a label cut by any
 * other geometry kernel would be a different part from the one the site ships.
 *
 * Off the main thread because a render is ~2s, almost all of it parsing.
 *
 * THREE SILENT FAILURES ARE GUARDED HERE. Each was reproduced, and each ends in exit code
 * 0 with a plausible STL, so none of them would ever surface on its own:
 *
 *   1. No font mounted. OpenSCAD substitutes nothing and exports a filter byte-identical
 *      to the unlabelled one. The only trace is a "Can't get font" line on stderr.
 *   2. A reused Module instance. A second callMain returns the FIRST render's geometry,
 *      which would ship one unit's name on every filter in the rack. Hence a fresh
 *      instance per render -- it costs ~25ms, against ~1.9s of render.
 *   3. An overlong label. Glyphs past the hexagon's flat remove LESS material rather than
 *      more, so the part stays valid and one body. --enable=textmetrics is what makes
 *      dust.scad's width assert fire; without it the assert reads undef and passes.
 */

import { cadSources } from '../lib/cad-sources';
import { engravedLabel } from '../lib/labels';

export interface EngraveRequest {
  id: number;
  labelTop: string;
  labelBottom: string;
  /** Facet count of the published unlabelled filter; the engraved mesh must exceed it. */
  blankTriangles: number;
}

export type EngraveResponse =
  | { id: number; ok: true; stl: Uint8Array }
  | { id: number; ok: false; error: string };

/** Only the handful of Emscripten surface this uses. */
interface ScadFS {
  mkdir(path: string): void;
  writeFile(path: string, data: Uint8Array | string): void;
  readFile(path: string): Uint8Array;
}
interface ScadModule {
  FS: ScadFS;
  callMain(args: string[]): number;
}
type ScadFactory = (options: {
  noInitialRun: boolean;
  wasmBinary: ArrayBuffer;
  print(line: string): void;
  printErr(line: string): void;
}) => Promise<ScadModule>;

const FONT_PATH = '/fonts/LiberationSans-Bold.ttf';
const SOURCE_ROOT = '/cad';
const OUTPUT = '/dust.stl';

const assetUrl = (path: string): string =>
  new URL(import.meta.env.BASE_URL + path, self.location.href).href;

interface Runtime {
  factory: ScadFactory;
  wasmBinary: ArrayBuffer;
  font: Uint8Array;
}

/**
 * Fetched once and reused. These three are immutable; it is the Module built FROM them
 * that must never be reused.
 */
let runtime: Promise<Runtime> | null = null;

function loadRuntime(): Promise<Runtime> {
  runtime ??= (async () => {
    const [glue, wasm, font] = await Promise.all([
      // The glue is fetched at build time into public/wasm by scripts/fetch-openscad-wasm.sh,
      // so it is not part of the bundle and Vite must not try to resolve it. A fresh clone
      // has not run that script yet, and the browser's own message for a missing module
      // ("Failed to fetch dynamically imported module") names neither the file nor the fix.
      (import(/* @vite-ignore */ assetUrl('wasm/openscad.js')) as Promise<{ default: ScadFactory }>)
        .catch(() => {
          throw new Error(
            'The OpenSCAD runtime is missing. Run scripts/fetch-openscad-wasm.sh and reload.',
          );
        }),
      fetchBinary('wasm/openscad.wasm'),
      fetchBinary('fonts/LiberationSans-Bold.ttf'),
    ]);
    // Handing the bytes over directly means the glue never has to locate the .wasm itself,
    // which is the part of its loader that assumes a bundler-controlled URL.
    return { factory: glue.default, wasmBinary: wasm, font: new Uint8Array(font) };
    // Caching the promise is the point, but caching a REJECTED one would make a dropped
    // connection permanent for the life of the page. Clearing it lets the next label retry.
  })().catch((error: unknown) => {
    runtime = null;
    throw error;
  });
  return runtime;
}

async function fetchBinary(path: string): Promise<ArrayBuffer> {
  const url = assetUrl(path);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${path} — ${res.status} ${res.statusText}`);
  return res.arrayBuffer();
}

function mountSources(fs: ScadFS): void {
  const made = new Set<string>();
  const mkdirp = (dir: string) => {
    let path = '';
    for (const segment of dir.split('/').filter(Boolean)) {
      path += `/${segment}`;
      if (made.has(path)) continue;
      made.add(path);
      // Already-exists is the normal case for a shared parent, and Emscripten signals it
      // by throwing rather than by a return code.
      try {
        fs.mkdir(path);
      } catch {
        /* already there */
      }
    }
  };

  for (const [relative, text] of Object.entries(cadSources)) {
    const full = `${SOURCE_ROOT}/${relative}`;
    mkdirp(full.slice(0, full.lastIndexOf('/')));
    fs.writeFile(full, text);
  }
}

/** Facet count of a binary STL: 80-byte header, then a uint32. */
const facetCount = (stl: Uint8Array): number =>
  new DataView(stl.buffer, stl.byteOffset, stl.byteLength).getUint32(80, true);

/**
 * The assert message dust.scad raises for an overlong label, which names the actual
 * millimetres. Matched on the sentence rather than on the surrounding quoting, because the
 * trace nests quotes and varies with the OpenSCAD build.
 */
const WIDTH_ASSERT = /dust label ".*?" is [\d.]+mm wide; the band's usable flat is [\d.]+mm[^"]*/;

function explain(log: readonly string[]): string {
  const joined = log.join('\n');
  const width = WIDTH_ASSERT.exec(joined);
  if (width) return width[0].trim();
  const errors = log.filter((line) => line.startsWith('ERROR:'));
  return errors.length > 0 ? errors.join('\n') : 'OpenSCAD failed without reporting a reason';
}

async function engrave(request: EngraveRequest): Promise<Uint8Array> {
  const { factory, wasmBinary, font } = await loadRuntime();

  // Re-sanitised at the splice itself. The label is interpolated into an OpenSCAD -D
  // argument, so a quote in it would close the string and run as code -- and this is the
  // one place that is true, no matter which caller got there.
  const top = engravedLabel(request.labelTop);
  const bottom = engravedLabel(request.labelBottom);

  const log: string[] = [];
  const module = await factory({
    noInitialRun: true,
    wasmBinary,
    print: (line) => log.push(line),
    printErr: (line) => log.push(line),
  });

  mountSources(module.FS);
  module.FS.mkdir('/fonts');
  module.FS.writeFile(FONT_PATH, font);

  const code = module.callMain([
    '--backend',
    'Manifold',
    // Not optional: this is what lets the width assert actually evaluate.
    '--enable=textmetrics',
    '--render',
    '--export-format=binstl',
    '-o',
    OUTPUT,
    '-D',
    'body_part="dust"',
    '-D',
    'show_sbc=false',
    '-D',
    'show_antennas=false',
    '-D',
    'enable_wifi_antennas=false',
    '-D',
    `dust_label_top="${top}"`,
    '-D',
    `dust_label_bottom="${bottom}"`,
    `${SOURCE_ROOT}/body.scad`,
  ]);

  // The exit code alone is not a verdict: an assert that fires mid-render prints ERROR and
  // OpenSCAD still exports a valid STL at exit 0 (measured, via an assert smuggled in
  // through a label before the allowlist closed that door). So any ERROR at all is a
  // failure, whatever the process claims.
  if (code !== 0 || log.some((line) => line.startsWith('ERROR:'))) throw new Error(explain(log));
  if (log.some((line) => line.includes("Can't get font"))) {
    throw new Error('The engraving font did not load, so the filter came out blank.');
  }

  const stl = module.FS.readFile(OUTPUT);
  // The outcome check behind the two cause checks: whatever went wrong, a filter that was
  // actually engraved has more facets than the blank one CI published.
  if (facetCount(stl) <= request.blankTriangles) {
    throw new Error('The engraving removed no material — refusing to ship a blank filter.');
  }
  return stl;
}

// One render at a time. Each holds a full OpenSCAD heap, and a rack of six labels would
// otherwise instantiate six at once for no gain -- the worker has one thread regardless.
let queue: Promise<void> = Promise.resolve();

self.onmessage = (event: MessageEvent<EngraveRequest>) => {
  const request = event.data;
  queue = queue.then(async () => {
    try {
      const stl = await engrave(request);
      const response: EngraveResponse = { id: request.id, ok: true, stl };
      self.postMessage(response, [stl.buffer]);
    } catch (error) {
      const response: EngraveResponse = {
        id: request.id,
        ok: false,
        error: error instanceof Error ? error.message : 'Engraving failed',
      };
      self.postMessage(response);
    }
  });
};

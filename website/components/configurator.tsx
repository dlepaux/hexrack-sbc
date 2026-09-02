import { useCallback, useEffect, useMemo, useState } from 'react';
import type { Manifest } from '../types/manifest';
import {
  cellKey,
  connectedComponent,
  deriveRack,
  unitLabels,
  type CellKey,
  type Unit,
} from '../lib/rack';
import { resolveRack } from '../lib/resolve';
import { PRESETS } from '../lib/presets';
import { decodeState, encodeState } from '../lib/url-state';
import {
  LABEL_MAX_CHARS,
  labelIsTooWide,
  measureLabelMm,
  sanitiseLabel,
} from '../lib/labels';
import { HexGrid } from './hex-grid';
import { BuildSheet } from './build-sheet';

/** The TTF the worker mounts into OpenSCAD. Measuring any other font would make the gate a lie. */
const FONT_URL = `${import.meta.env.BASE_URL}fonts/LiberationSans-Bold.ttf`;

interface ConfiguratorProps {
  manifest: Manifest;
  baseUrl: string;
}

function Segmented<T extends string | boolean>({
  label,
  hint,
  value,
  options,
  onChange,
}: {
  label: string;
  hint?: string;
  value: T;
  options: Array<{ value: T; label: string }>;
  onChange: (v: T) => void;
}) {
  return (
    <div className="flex flex-wrap items-center gap-3">
      <div className="min-w-[7rem]">
        <div className="text-sm font-medium text-zinc-200">{label}</div>
        {hint && <div className="text-xs text-zinc-500">{hint}</div>}
      </div>
      <div className="inline-flex gap-1 rounded-lg border border-zinc-800 bg-zinc-900 p-1">
        {options.map((o) => (
          <button
            key={String(o.value)}
            type="button"
            aria-pressed={o.value === value}
            onClick={() => onChange(o.value)}
            className={
              o.value === value
                ? 'rounded-md bg-amber-500 px-3 py-1.5 text-sm font-semibold text-black'
                : 'rounded-md px-3 py-1.5 text-sm text-zinc-400 transition hover:text-zinc-100'
            }
          >
            {o.label}
          </button>
        ))}
      </div>
    </div>
  );
}

/**
 * One engraved line, with a live width readout.
 *
 * The bound is a WIDTH, not a character count, and the two are not interchangeable:
 * "NODE-01-RACK-A-XY" and "NODE-01-RACK-ABCD" are both 17 characters and span 70.8mm and
 * 74.1mm. So the field measures the actual glyphs in the actual font.
 *
 * The gate is a courtesy, not the guarantee. If the font has not loaded the measurement
 * returns null and nothing is claimed here -- the CAD assert still fires in the worker and
 * the build sheet refuses the download. Better a warning that sometimes arrives late than
 * one that is sometimes wrong.
 */
function LabelField({
  label,
  value,
  limitMm,
  sizeMm,
  onChange,
}: {
  label: string;
  value: string;
  limitMm: number;
  sizeMm: number;
  onChange: (v: string) => void;
}) {
  const [widthMm, setWidthMm] = useState<number | null>(null);

  useEffect(() => {
    let cancelled = false;
    void measureLabelMm(value.trim(), sizeMm, FONT_URL).then((mm) => {
      if (!cancelled) setWidthMm(mm);
    });
    return () => {
      cancelled = true;
    };
  }, [value, sizeMm]);

  const tooWide = labelIsTooWide(widthMm, limitMm);
  // Slugged: a space here would produce an id that aria-describedby and every CSS selector
  // silently fail to resolve.
  const id = `dust-label-${label.toLowerCase().replace(/\s+/g, '-')}`;

  return (
    <div className="flex flex-wrap items-center gap-3">
      <div className="min-w-[7rem]">
        <label htmlFor={id} className="text-sm font-medium text-zinc-200">
          {label}
        </label>
        <div className="text-xs text-zinc-500">Dust filter</div>
      </div>
      <div className="min-w-0 flex-1">
        <input
          id={id}
          type="text"
          value={value}
          maxLength={LABEL_MAX_CHARS}
          placeholder="leave empty for none"
          aria-invalid={tooWide}
          aria-describedby={`${id}-width`}
          onChange={(e) => onChange(sanitiseLabel(e.target.value))}
          className={`w-full rounded-lg border bg-zinc-950 px-3 py-1.5 font-mono text-sm text-zinc-100 outline-none transition placeholder:text-zinc-600 ${
            tooWide ? 'border-red-600 focus:border-red-500' : 'border-zinc-800 focus:border-amber-600'
          }`}
        />
        <div
          id={`${id}-width`}
          className={`mt-1 font-mono text-[10px] ${tooWide ? 'text-red-400' : 'text-zinc-600'}`}
        >
          {widthMm === null
            ? `up to ${limitMm.toFixed(1)}mm wide`
            : `${widthMm.toFixed(1)} / ${limitMm.toFixed(1)} mm${tooWide ? ' — too wide to engrave' : ''}`}
        </div>
      </div>
    </div>
  );
}

export function Configurator({ manifest, baseUrl }: ConfiguratorProps) {
  const axes = manifest.axes;

  const initial = useMemo(() => {
    const fromUrl = window.location.hash.startsWith('#b=')
      ? decodeState(window.location.hash.slice(3))
      : null;
    if (fromUrl && axes.ventPattern.values.includes(fromUrl.vent)) return fromUrl;
    return {
      units: new Map<CellKey, Unit>(
        PRESETS[1].cells.map(([q, r]) => [
          cellKey({ q, r }),
          { board: axes.board.values[0], antennas: false, labelTop: '', labelBottom: '' },
        ]),
      ),
      vent: axes.ventPattern.default,
      circle: true,
    };
  }, [axes]);

  const [units, setUnits] = useState<Map<CellKey, Unit>>(initial.units);
  const [vent, setVent] = useState(initial.vent);
  const [circle, setCircle] = useState(initial.circle);
  const [selected, setSelected] = useState<CellKey>(() => [...initial.units.keys()][0]);

  // Memoised because it is an object literal: recreating it every render would defeat the
  // memoisation of everything downstream that takes it as a dependency.
  const pitch = useMemo(
    () => ({ column: manifest.layout.gridPitch.column, row: manifest.layout.gridPitch.row }),
    [manifest.layout.gridPitch.column, manifest.layout.gridPitch.row],
  );
  const derived = useMemo(() => deriveRack(units, pitch).cells, [units, pitch]);
  const rack = useMemo(
    () => resolveRack(manifest, { units, ventPattern: vent, frontCircle: circle }),
    [manifest, units, vent, circle],
  );
  const labels = useMemo(() => unitLabels(units, pitch), [units, pitch]);

  const selectedUnit = units.get(selected);

  const addUnit = useCallback(
    (key: CellKey) => {
      setUnits((prev) => {
        const next = new Map(prev);
        next.set(key, { board: axes.board.values[0], antennas: false, labelTop: '', labelBottom: '' });
        return next;
      });
      setSelected(key);
    },
    [axes.board.values],
  );

  const removeUnit = useCallback((key: CellKey) => {
    setUnits((prev) => {
      if (prev.size <= 1) return prev;
      const next = new Map(prev);
      next.delete(key);
      // Removing a unit can strand others. A rack in two pieces is two racks, so drop
      // whatever is no longer attached rather than quietly resolving parts for it.
      const reachable = connectedComponent(next);
      for (const k of [...next.keys()]) if (!reachable.has(k)) next.delete(k);
      setSelected((cur) => (next.has(cur) ? cur : [...next.keys()][0]));
      return next;
    });
  }, []);

  const patchSelected = useCallback(
    (patch: Partial<Unit>) => {
      setUnits((prev) => {
        const unit = prev.get(selected);
        if (!unit) return prev;
        const next = new Map(prev);
        next.set(selected, { ...unit, ...patch });
        return next;
      });
    },
    [selected],
  );

  const applyPreset = useCallback(
    (cells: Array<[number, number]>) => {
      const next = new Map<CellKey, Unit>(
        cells.map(([q, r]) => [cellKey({ q, r }), { board: axes.board.values[0], antennas: false, labelTop: '', labelBottom: '' }]),
      );
      setUnits(next);
      setSelected([...next.keys()][0]);
    },
    [axes.board.values],
  );

  const copyLink = useCallback(() => {
    const url = `${window.location.origin}${window.location.pathname}#b=${encodeState(units, vent, circle)}`;
    window.history.replaceState(null, '', url);
    void navigator.clipboard?.writeText(url);
  }, [units, vent, circle]);

  const d = derived.get(selected);

  return (
    <section className="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_23rem]">
      <div className="space-y-4">
        <div className="rounded-xl border border-zinc-800 bg-zinc-900/60">
          <div className="flex flex-wrap items-baseline gap-3 border-b border-zinc-800 px-5 py-4">
            <h2 className="text-sm font-semibold text-zinc-100">1 · Your rack</h2>
            <p className="ml-auto text-xs text-zinc-500">
              Click a dotted cell to add a unit · click a unit to select it
            </p>
          </div>
          <div className="p-5">
            <div className="flex flex-wrap gap-2">
              {PRESETS.map((p) => (
                <button
                  key={p.id}
                  type="button"
                  onClick={() => applyPreset(p.cells)}
                  className="rounded-lg border border-zinc-800 bg-zinc-900 px-3 py-1.5 text-xs text-zinc-300 transition hover:border-amber-600 hover:text-amber-400"
                >
                  {p.name}
                </button>
              ))}
            </div>

            <div className="mt-4 rounded-lg border border-zinc-800 bg-zinc-950/60">
              <HexGrid
                units={units}
                derived={derived}
                selected={selected}
                boardLabels={axes.board.labels}
                onSelect={setSelected}
                onAdd={addUnit}
                onRemove={removeUnit}
              />
            </div>

            <div className="mt-3 flex flex-wrap gap-x-6 gap-y-1 text-xs text-zinc-500">
              <span>
                <i className="mr-2 inline-block h-1 w-4 rounded bg-amber-500 align-middle" />
                Rail (male) — on Back Top
              </span>
              <span>
                <i className="mr-2 inline-block h-1 w-4 rounded bg-cyan-400/80 align-middle" />
                Groove (female) — Back Bottom + Back Face
              </span>
            </div>
            <p className="mt-3 border-l-2 border-amber-700/60 pl-3 text-xs leading-relaxed text-zinc-500">
              Joins are derived from which units touch, so you never pick{' '}
              <span className="font-mono">top-left</span> versus{' '}
              <span className="font-mono">bottom-right</span>. One derived set feeds both Back Bottom
              and Back Face, so the pairing those two parts require cannot be got wrong.
            </p>
          </div>
        </div>

        {selectedUnit && (
          <div className="rounded-xl border border-zinc-800 bg-zinc-900/60">
            <div className="flex flex-wrap items-baseline gap-3 border-b border-zinc-800 px-5 py-4">
              <h2 className="text-sm font-semibold text-zinc-100">
                2 · Unit <span className="font-mono text-amber-500">{labels.get(selected)}</span>
              </h2>
              <p className="ml-auto text-xs text-zinc-500">Applies to the selected unit only</p>
            </div>
            <div className="space-y-4 p-5">
              <Segmented
                label="Board"
                value={selectedUnit.board}
                options={axes.board.values.map((b) => ({
                  value: b,
                  label: axes.board.labels[b] ?? b,
                }))}
                onChange={(board) => patchSelected({ board })}
              />
              <Segmented
                label="WiFi antennas"
                hint="Back panel"
                value={selectedUnit.antennas}
                options={[
                  { value: false, label: 'None' },
                  { value: true, label: 'Two SMA' },
                ]}
                onChange={(antennas) => patchSelected({ antennas })}
              />
              <LabelField
                label="Top line"
                value={selectedUnit.labelTop}
                limitMm={manifest.labelLimit.safeWidthMm}
                sizeMm={manifest.labelLimit.sizeMm}
                onChange={(labelTop) => patchSelected({ labelTop })}
              />
              <LabelField
                label="Bottom line"
                value={selectedUnit.labelBottom}
                limitMm={manifest.labelLimit.safeWidthMm}
                sizeMm={manifest.labelLimit.sizeMm}
                onChange={(labelBottom) => patchSelected({ labelBottom })}
              />
              <p className="border-l-2 border-amber-700/60 pl-3 text-xs leading-relaxed text-zinc-500">
                Engraved into the dust filter's front face and cut in your browser by the same
                OpenSCAD that builds every other part here — so a labelled filter is the published
                one plus the text, not a lookalike. Leave both empty and you get the published file.
              </p>
              {d && (
                <div className="flex flex-wrap items-center gap-3">
                  <div className="min-w-[7rem]">
                    <div className="text-sm font-medium text-zinc-200">Joins</div>
                    <div className="text-xs text-zinc-500">Derived</div>
                  </div>
                  <div className="flex flex-wrap gap-2 font-mono text-xs">
                    <span className="rounded bg-amber-500/15 px-2 py-1 text-amber-400">
                      rails {d.male.join(' · ') || 'none'}
                    </span>
                    <span className="rounded bg-cyan-400/10 px-2 py-1 text-cyan-300">
                      grooves {d.female.join(' · ') || 'none'}
                    </span>
                    {d.feet && (
                      <span className="rounded bg-zinc-800 px-2 py-1 text-zinc-400">+ feet</span>
                    )}
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

        <div className="rounded-xl border border-zinc-800 bg-zinc-900/60">
          <div className="flex flex-wrap items-baseline gap-3 border-b border-zinc-800 px-5 py-4">
            <h2 className="text-sm font-semibold text-zinc-100">3 · Front look</h2>
            <p className="ml-auto text-xs text-zinc-500">Applies to every unit</p>
          </div>
          <div className="space-y-4 p-5">
            <Segmented
              label="Vent pattern"
              hint="Face panel"
              value={vent}
              options={axes.ventPattern.values.map((v) => ({
                value: v,
                label: v.charAt(0).toUpperCase() + v.slice(1),
              }))}
              onChange={setVent}
            />
            <Segmented
              label="Front circle"
              hint="Traced at the fan bore"
              value={circle}
              options={[
                { value: true, label: 'On' },
                { value: false, label: 'Off' },
              ]}
              onChange={setCircle}
            />
          </div>
        </div>
      </div>

      <div className="lg:sticky lg:top-6">
        <BuildSheet rack={rack} baseUrl={baseUrl} commit={manifest.commit} onCopyLink={copyLink} />
      </div>
    </section>
  );
}

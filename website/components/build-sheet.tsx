import { useState } from 'react';
import { Download, Link2, AlertTriangle, Loader2 } from 'lucide-react';
import JSZip from 'jszip';
import { saveAs } from 'file-saver';
import type { ResolvedPart, ResolvedRack } from '../lib/resolve';
import { useEngravedMeshes, type MeshState } from '../hooks/use-engraved-meshes';

interface BuildSheetProps {
  rack: ResolvedRack;
  baseUrl: string;
  commit: string;
  onCopyLink: () => void;
}

function formatBytes(b: number): string {
  if (b >= 1024 * 1024) return `${(b / (1024 * 1024)).toFixed(1)} MB`;
  if (b >= 1024) return `${Math.round(b / 1024)} KB`;
  return `${b} B`;
}

/** The name this part is downloaded and zipped under. */
const fileName = (p: ResolvedPart): string =>
  p.source.kind === 'prebuilt' ? p.source.file : p.source.entry;

export function BuildSheet({ rack, baseUrl, commit, onCopyLink }: BuildSheetProps) {
  const [progress, setProgress] = useState({ current: 0, total: 0 });
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const busy = progress.total > 0;

  const meshes = useEngravedMeshes(rack.parts);

  // Only the engraved parts can be unready, and only they contribute an unknown size --
  // which is why the resolver hands over `prebuiltBytes` rather than a total that would
  // have to be a guess.
  const engraved = rack.parts.filter((p) => p.source.kind === 'engraved');
  const engravedStates = engraved.map((p) => meshes.get(p.key));
  const engravedBytes = engraved.reduce((n, p) => {
    const state = meshes.get(p.key);
    return n + (state?.status === 'ready' ? state.bytes * p.quantity : 0);
  }, 0);
  const waiting = engravedStates.some((s) => s === undefined || s.status === 'engraving');
  const broken = engravedStates.some((s) => s?.status === 'failed');
  const knownBytes = rack.prebuiltBytes + engravedBytes;

  const handleDownload = async () => {
    setError(null);
    const zip = new JSZip();
    setProgress({ current: 0, total: rack.parts.length });

    try {
      for (const [i, part] of rack.parts.entries()) {
        if (part.source.kind === 'prebuilt') {
          const response = await fetch(`${baseUrl}${part.source.file}`);
          // Without this a 404 page is zipped up as an STL and only fails in the slicer.
          if (!response.ok) {
            throw new Error(`${part.source.file} — ${response.status} ${response.statusText}`);
          }
          zip.file(part.source.file, await response.blob());
        } else {
          // The engraved equivalent of that 404 guard: never zip a filter we could not cut,
          // because the sheet promises it and the slicer would never miss it.
          const state = meshes.get(part.key);
          if (state?.status !== 'ready') {
            throw new Error(
              `${part.source.entry} — ${state?.status === 'failed' ? state.error : 'not engraved yet'}`,
            );
          }
          zip.file(part.source.entry, state.blob);
        }
        setProgress({ current: i + 1, total: rack.parts.length });
      }

      const manifestText = [
        `HexRack SBC — ${rack.unitCount} unit${rack.unitCount === 1 ? '' : 's'}`,
        `build ${commit}`,
        '',
        'PARTS',
        ...rack.parts.map((p) => {
          const engraving =
            p.source.kind === 'engraved'
              ? `   engraved "${[p.source.labelTop, p.source.labelBottom].filter(Boolean).join('" / "')}"`
              : '';
          return `  ${p.quantity} x  ${p.name.padEnd(14)} ${fileName(p)}${engraving}`;
        }),
        '',
        'HARDWARE',
        ...rack.hardware.map((h) => `  ${h.quantity} x  ${h.name}`),
      ].join('\n');
      zip.file('build-sheet.txt', manifestText);

      saveAs(await zip.generateAsync({ type: 'blob' }), `hexrack-${rack.unitCount}unit-${commit}.zip`);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Download failed');
    } finally {
      setProgress({ current: 0, total: 0 });
    }
  };

  const handleCopy = () => {
    onCopyLink();
    setCopied(true);
    setTimeout(() => setCopied(false), 2200);
  };

  const downloadLabel = () => {
    if (busy) return `Packing ${progress.current}/${progress.total}…`;
    if (broken) return 'Fix the engraving to download';
    if (waiting) return 'Engraving…';
    return `Download ${rack.parts.length} files · ${formatBytes(knownBytes)}`;
  };

  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/60">
      <div className="px-5 pt-5 pb-3 border-b border-zinc-800">
        <h2 className="text-sm font-semibold text-zinc-100">Your build</h2>
        <div className="mt-2 flex items-baseline gap-2">
          <span className="text-3xl font-bold tabular-nums text-zinc-50">{rack.totalParts}</span>
          <span className="text-xs text-zinc-500">parts</span>
          <span className="ml-3 text-3xl font-bold tabular-nums text-zinc-50">{rack.unitCount}</span>
          <span className="text-xs text-zinc-500">units</span>
        </div>
      </div>

      {rack.warnings.length > 0 && (
        <div className="mx-5 mt-4 flex gap-2 rounded-lg bg-amber-500/10 p-3 text-xs text-amber-300">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" aria-hidden />
          <ul className="space-y-1">
            {rack.warnings.map((w) => (
              <li key={w.cell}>
                <span className="font-mono">{w.cell}</span> {w.message}
              </li>
            ))}
          </ul>
        </div>
      )}

      {rack.missing.length > 0 && (
        <div className="mx-5 mt-4 rounded-lg bg-red-500/10 p-3 text-xs text-red-300">
          This build is missing {rack.missing.length} file(s): {rack.missing.join(', ')}. The
          published parts list may be out of date — please report it.
        </div>
      )}

      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-[10px] uppercase tracking-widest text-zinc-500">
              <th className="px-5 pb-2 pt-4 text-left font-semibold">Part</th>
              <th className="px-2 pb-2 pt-4 text-right font-semibold">Qty</th>
              <th className="px-5 pb-2 pt-4 text-right font-semibold">Size</th>
            </tr>
          </thead>
          <tbody>
            {rack.parts.map((p) => (
              <tr key={p.key} className="border-t border-zinc-800/70 align-top">
                <td className="px-5 py-2.5">
                  <div className="font-medium text-zinc-200">{p.name}</div>
                  <div className="break-all font-mono text-[10px] text-zinc-600">{fileName(p)}</div>
                  {p.note && (
                    <span className="mt-1 inline-block rounded bg-zinc-800 px-1.5 py-0.5 font-mono text-[10px] text-zinc-400">
                      {p.note}
                    </span>
                  )}
                  {p.source.kind === 'engraved' && (
                    <EngravingNote part={p} state={meshes.get(p.key)} />
                  )}
                </td>
                <td className="px-2 py-2.5 text-right font-mono font-semibold text-zinc-300">
                  &times;{p.quantity}
                </td>
                <td className="px-5 py-2.5 text-right font-mono text-xs text-zinc-500">
                  <SizeCell part={p} state={meshes.get(p.key)} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="grid gap-2 border-t border-zinc-800 p-5">
        <button
          onClick={handleDownload}
          disabled={busy || waiting || broken || rack.parts.length === 0}
          className="flex w-full items-center justify-center gap-2 rounded-lg bg-gradient-to-r from-amber-500 to-orange-500 px-4 py-3 font-semibold text-black transition hover:from-amber-600 hover:to-orange-600 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <Download className="h-4 w-4" aria-hidden />
          {downloadLabel()}
        </button>
        <button
          onClick={handleCopy}
          className="w-full rounded-lg border border-zinc-700 px-4 py-2.5 text-sm font-medium text-zinc-300 transition hover:border-amber-600 hover:text-amber-400"
        >
          <Link2 className="mr-2 inline h-4 w-4" aria-hidden />
          {copied ? 'Link copied' : 'Copy configuration link'}
        </button>
        {error && <p className="text-xs text-red-400">{error}</p>}
      </div>

      <div className="border-t border-zinc-800 px-5 py-4">
        <h3 className="font-mono text-[10px] uppercase tracking-widest text-zinc-500">
          Hardware you supply
        </h3>
        <ul className="mt-2 space-y-1 text-xs text-zinc-400">
          {rack.hardware.map((h) => (
            <li key={h.name} className="flex justify-between gap-3">
              <span>{h.name}</span>
              <span className="font-mono tabular-nums text-zinc-300">&times;{h.quantity}</span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

/** What the engraving says, and — when it went wrong — what OpenSCAD said about it. */
function EngravingNote({ part, state }: { part: ResolvedPart; state: MeshState | undefined }) {
  if (part.source.kind !== 'engraved') return null;
  const text = [part.source.labelTop, part.source.labelBottom].filter(Boolean).join(' · ');
  return (
    <>
      <span className="mt-1 ml-1 inline-block rounded bg-amber-500/15 px-1.5 py-0.5 font-mono text-[10px] text-amber-400">
        {text}
      </span>
      {state?.status === 'failed' && (
        <p className="mt-1 text-[10px] leading-relaxed text-red-400">{state.error}</p>
      )}
    </>
  );
}

/**
 * A prebuilt part's size is measured; an engraved one's does not exist until it is cut, so
 * the cell says so rather than showing the unlabelled part's figure — which is 14x smaller.
 */
function SizeCell({ part, state }: { part: ResolvedPart; state: MeshState | undefined }) {
  if (part.source.kind === 'prebuilt') {
    return <>{formatBytes(part.source.bytes * part.quantity)}</>;
  }
  if (state?.status === 'ready') return <>{formatBytes(state.bytes * part.quantity)}</>;
  if (state?.status === 'failed') return <span className="text-red-400">failed</span>;
  return <Loader2 className="ml-auto h-3 w-3 animate-spin text-zinc-600" aria-label="Engraving" />;
}

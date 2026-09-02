import { useCallback, useEffect, useRef, useState } from 'react';
import type { ResolvedPart } from '../lib/resolve';
import type { EngraveRequest, EngraveResponse } from '../workers/engrave.worker';

/**
 * Meshes the browser has to cut, because a per-unit label is not something CI could have
 * pre-built.
 *
 * LAZY ON PURPOSE. The worker -- and with it a ~3MB runtime -- is created on the first
 * engraved part and never before, so the overwhelmingly common unlabelled configuration
 * downloads nothing extra.
 *
 * Results are cached by the part's key, which already encodes the label, so backspacing
 * over a name and typing it again is free, and every unit sharing a label shares one
 * render.
 *
 * ponytail: the cache is never evicted, so a session that settles on many distinct labels
 * holds them all — bounded in practice by how much a person types, at ~70KB a mesh, next
 * to the 11MB runtime the same page already fetched. Add an LRU keyed on the live part set
 * if that ever stops being true; evicting a key still on screen would re-trigger its
 * render, so any eviction has to skip the current parts.
 */
export type MeshState =
  | { status: 'engraving' }
  | { status: 'ready'; blob: Blob; bytes: number }
  | { status: 'failed'; error: string };

/** Long enough that typing a name does not queue a render per keystroke. */
const SETTLE_MS = 600;

export function useEngravedMeshes(parts: readonly ResolvedPart[]): ReadonlyMap<string, MeshState> {
  const [meshes, setMeshes] = useState<ReadonlyMap<string, MeshState>>(new Map());
  const worker = useRef<Worker | null>(null);
  const pending = useRef(new Map<number, string>());
  const nextId = useRef(0);

  useEffect(
    () => () => {
      worker.current?.terminate();
      worker.current = null;
    },
    [],
  );

  const request = useCallback((part: ResolvedPart) => {
    if (part.source.kind !== 'engraved') return;

    worker.current ??= (() => {
      const w = new Worker(new URL('../workers/engrave.worker.ts', import.meta.url), {
        type: 'module',
      });
      w.onmessage = (event: MessageEvent<EngraveResponse>) => {
        const response = event.data;
        const key = pending.current.get(response.id);
        if (key === undefined) return;
        pending.current.delete(response.id);
        setMeshes((prev) =>
          new Map(prev).set(
            key,
            response.ok
              ? {
                  status: 'ready',
                  blob: new Blob([response.stl as BlobPart], { type: 'model/stl' }),
                  bytes: response.stl.byteLength,
                }
              : { status: 'failed', error: response.error },
          ),
        );
      };
      // A worker that dies outright (a failed wasm fetch, an out-of-memory kill) reports
      // through onerror, not onmessage. Left unhandled, every row would sit at "Engraving"
      // for ever, which reads as slow rather than as broken.
      w.onerror = () => {
        const stranded = [...pending.current.values()];
        pending.current.clear();
        setMeshes((prev) => {
          const next = new Map(prev);
          for (const key of stranded) {
            next.set(key, { status: 'failed', error: 'The engraver failed to start.' });
          }
          return next;
        });
      };
      return w;
    })();

    const id = nextId.current++;
    pending.current.set(id, part.key);
    setMeshes((prev) => new Map(prev).set(part.key, { status: 'engraving' }));

    const message: EngraveRequest = {
      id,
      labelTop: part.source.labelTop,
      labelBottom: part.source.labelBottom,
      blankTriangles: part.source.blankTriangles,
    };
    worker.current.postMessage(message);
  }, []);

  useEffect(() => {
    const missing = parts.filter((p) => p.source.kind === 'engraved' && !meshes.has(p.key));
    if (missing.length === 0) return;

    const timer = setTimeout(() => missing.forEach(request), SETTLE_MS);
    return () => clearTimeout(timer);
  }, [parts, meshes, request]);

  return meshes;
}

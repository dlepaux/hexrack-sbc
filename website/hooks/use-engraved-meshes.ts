import { useCallback, useEffect, useRef, useState } from 'react';
import type { ResolvedPart } from '../lib/resolve';
import type { EngraveRequest, EngraveResponse } from '../workers/engrave.worker';

/**
 * Meshes the browser has to cut, because a per-unit label is not something CI could have
 * pre-built.
 *
 * CUT ON DOWNLOAD, not while typing. Engraving is the expensive half of this feature --
 * a ~3MB runtime and ~2s a label -- and rendering on a debounce spends it on every name
 * the user tries on the way to the one they keep. The label field already measures its
 * own width instantly, so the fast feedback that matters does not depend on a render;
 * what waiting costs is only the size figure in the build sheet, which fills in once a
 * download has cut the part.
 *
 * The worker is created on the first engrave and never before, so a rack with no labels
 * fetches nothing extra at all.
 *
 * Results are cached by the part's key, which already encodes the label, so a second
 * download is instant and every unit sharing a label shares one render.
 *
 * ponytail: the cache is never evicted, so a session that downloads many distinct labels
 * holds them all -- bounded in practice by how often a person downloads, at ~70KB a mesh,
 * next to the 11MB runtime the same page already fetched. Add an LRU keyed on the live
 * part set if that ever stops being true; evicting a key still on screen would only cost
 * a re-render on the next download, but it must not drop one mid-flight.
 */
export type MeshState =
  | { status: 'engraving' }
  | { status: 'ready'; blob: Blob; bytes: number }
  | { status: 'failed'; error: string };

interface Pending {
  key: string;
  resolve: (blob: Blob) => void;
  reject: (error: Error) => void;
}

export interface EngravedMeshes {
  /** Per-part progress, for the build sheet's size column. */
  states: ReadonlyMap<string, MeshState>;
  /**
   * Cuts every engraved part not already cut, and resolves with the blob for each.
   * Rejects on the first failure, so a caller cannot zip up a filter that was never made.
   */
  ensure: (parts: readonly ResolvedPart[]) => Promise<ReadonlyMap<string, Blob>>;
}

export function useEngravedMeshes(): EngravedMeshes {
  const [states, setStates] = useState<ReadonlyMap<string, MeshState>>(new Map());
  const worker = useRef<Worker | null>(null);
  const pending = useRef(new Map<number, Pending>());
  const cache = useRef(new Map<string, Blob>());
  const nextId = useRef(0);

  useEffect(
    () => () => {
      worker.current?.terminate();
      worker.current = null;
    },
    [],
  );

  const getWorker = useCallback((): Worker => {
    worker.current ??= (() => {
      const w = new Worker(new URL('../workers/engrave.worker.ts', import.meta.url), {
        type: 'module',
      });

      w.onmessage = (event: MessageEvent<EngraveResponse>) => {
        const response = event.data;
        const waiter = pending.current.get(response.id);
        if (!waiter) return;
        pending.current.delete(response.id);

        if (response.ok) {
          const blob = new Blob([response.stl as BlobPart], { type: 'model/stl' });
          cache.current.set(waiter.key, blob);
          setStates((prev) =>
            new Map(prev).set(waiter.key, {
              status: 'ready',
              blob,
              bytes: response.stl.byteLength,
            }),
          );
          waiter.resolve(blob);
        } else {
          setStates((prev) =>
            new Map(prev).set(waiter.key, { status: 'failed', error: response.error }),
          );
          waiter.reject(new Error(response.error));
        }
      };

      // A worker that dies outright — a failed runtime fetch, an out-of-memory kill —
      // reports here, not through onmessage. Left unhandled, the download would hang for
      // ever on a promise nothing will ever settle.
      w.onerror = () => {
        const stranded = [...pending.current.values()];
        pending.current.clear();
        const error = new Error('The engraver stopped unexpectedly.');
        setStates((prev) => {
          const next = new Map(prev);
          for (const { key } of stranded) next.set(key, { status: 'failed', error: error.message });
          return next;
        });
        for (const { reject } of stranded) reject(error);
      };

      return w;
    })();
    return worker.current;
  }, []);

  const ensure = useCallback(
    async (parts: readonly ResolvedPart[]): Promise<ReadonlyMap<string, Blob>> => {
      const engraved = parts.filter((p) => p.source.kind === 'engraved');
      const done = new Map<string, Blob>();
      const wanted = engraved.filter((p) => {
        const cached = cache.current.get(p.key);
        if (cached) done.set(p.key, cached);
        return !cached;
      });
      if (wanted.length === 0) return done;

      const w = getWorker();
      setStates((prev) => {
        const next = new Map(prev);
        for (const p of wanted) next.set(p.key, { status: 'engraving' });
        return next;
      });

      const cut = wanted.map((part) => {
        if (part.source.kind !== 'engraved') throw new Error('unreachable');
        const id = nextId.current++;
        const message: EngraveRequest = {
          id,
          labelTop: part.source.labelTop,
          labelBottom: part.source.labelBottom,
          blankTriangles: part.source.blankTriangles,
        };
        const settled = new Promise<Blob>((resolve, reject) => {
          pending.current.set(id, { key: part.key, resolve, reject });
        });
        w.postMessage(message);
        return settled.then((blob) => done.set(part.key, blob));
      });

      // all, not allSettled: a filter we could not cut must abort the download rather
      // than quietly leave a part out of a zip the build sheet says contains it.
      await Promise.all(cut);
      return done;
    },
    [getWorker],
  );

  return { states, ensure };
}

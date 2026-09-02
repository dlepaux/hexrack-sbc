import { useEffect, useState } from 'react';
import { SCHEMA_VERSION, type Manifest } from '../types/manifest';

export function useManifest() {
  const [manifest, setManifest] = useState<Manifest | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      try {
        const res = await fetch(`${import.meta.env.BASE_URL}manifest.json`);
        if (!res.ok) throw new Error(`manifest.json — ${res.status} ${res.statusText}`);
        return (await res.json()) as Manifest;
      } catch (e) {
        // public/manifest.json and public/stl are build output and gitignored, so a fresh
        // clone has neither. Falling back to the committed fixture makes `npm run dev`
        // work without a local OpenSCAD run. Dev only — it never ships in the bundle.
        if (import.meta.env.DEV) {
          const fixture = await import('../fixtures/manifest.json');
          return fixture.default as unknown as Manifest;
        }
        throw e;
      }
    };

    load()
      .then((data) => {
        if (cancelled) return;
        if (data.schemaVersion !== SCHEMA_VERSION) {
          throw new Error(
            `This page expects manifest v${SCHEMA_VERSION} but the build published v${data.schemaVersion}. Try a hard refresh.`,
          );
        }
        setManifest(data);
        setLoading(false);
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : 'Failed to load the parts list');
        setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, []);

  return { manifest, loading, error };
}

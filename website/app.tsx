import { useState } from 'react';
import { useManifest } from './hooks/use-manifest';
import { Hero } from './components/hero';
import { BuildSteps } from './components/build-steps';
import { Configurator } from './components/configurator';
import { PartGroup } from './components/part-group';
import { Footer } from './components/footer';
import { Loading } from './components/loading';
import { ErrorState } from './components/error-state';

function App() {
  const { manifest, loading, error } = useManifest();
  const [showGallery, setShowGallery] = useState(false);

  if (loading) return <Loading />;
  if (error || !manifest) return <ErrorState message={error || 'No manifest found'} />;

  const baseUrl = `${import.meta.env.BASE_URL}stl/`;
  const galleryCount = manifest.groups.reduce((n, g) => n + g.parts.length, 0);

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100">
      <div className="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8">
        <Hero layout={manifest.layout} />

        <section id="configure" aria-labelledby="configure-heading" className="scroll-mt-6">
          <h2
            id="configure-heading"
            className="text-3xl font-bold tracking-tight text-zinc-50 [font-stretch:112.5%] md:text-4xl"
          >
            Build your rack
          </h2>
          <p className="mb-8 mt-3 max-w-[42rem] text-zinc-400">
            Place cells, choose a board for each, and pick a look. The preview and the parts list
            update with every change.
          </p>
          <Configurator manifest={manifest} baseUrl={baseUrl} />
        </section>

        <BuildSteps hardware={manifest.hardware} boards={manifest.axes.board} />

        {/* The full parts list stays available for people who know exactly what they want,
            but it is no longer the way most visitors are expected to find a file. */}
        <div className="border-t border-zinc-800 py-10">
          <button
            type="button"
            onClick={() => setShowGallery((v) => !v)}
            aria-expanded={showGallery}
            className="text-sm font-medium text-zinc-400 transition hover:text-amber-400"
          >
            {showGallery ? 'Hide' : 'Browse'} all {galleryCount} published parts
          </button>

          {showGallery && (
            <div className="mt-6 divide-y divide-zinc-800">
              {manifest.groups.map((group) => (
                <PartGroup key={group.id} group={group} baseUrl={baseUrl} />
              ))}
            </div>
          )}
        </div>

        <Footer commit={manifest.commit} generated={manifest.generated} />
      </div>
    </div>
  );
}

export default App;

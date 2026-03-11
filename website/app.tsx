import { useManifest } from './hooks/use-manifest';
import { Hero } from './components/hero';
import { Features } from './components/features';
import { PartGroup } from './components/part-group';
import { DownloadAllButton } from './components/download-all-button';
import { Footer } from './components/footer';
import { Loading } from './components/loading';
import { ErrorState } from './components/error-state';

function App() {
  const { manifest, loading, error } = useManifest();

  if (loading) {
    return <Loading />;
  }

  if (error || !manifest) {
    return <ErrorState message={error || 'No manifest found'} />;
  }

  const baseUrl = `${import.meta.env.BASE_URL}stl/`;

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
        <Hero 
          commit={manifest.commit} 
          generated={manifest.generated}
          assemblies={manifest.assemblies}
        />

        <Features />

        {/* Download All Section */}
        <div className="flex justify-center py-8">
          <DownloadAllButton manifest={manifest} baseUrl={baseUrl} />
        </div>

        {/* Parts Gallery */}
        <div className="divide-y divide-zinc-800">
          {manifest.groups.map((group) => (
            <PartGroup key={group.id} group={group} baseUrl={baseUrl} />
          ))}
        </div>

        <Footer />
      </div>
    </div>
  );
}

export default App;

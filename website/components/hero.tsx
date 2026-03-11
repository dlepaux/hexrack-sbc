import { Github } from 'lucide-react';
import { useState } from 'react';
import { STLViewer } from './stl-viewer';
import { STLModal } from './stl-modal';
import type { Assemblies } from '../types/manifest';

interface HeroProps {
  commit?: string;
  generated?: string;
  assemblies?: Assemblies;
}

export function Hero({ commit, generated, assemblies }: HeroProps) {
  const baseUrl = import.meta.env.BASE_URL;
  const [modalData, setModalData] = useState<{ url: string; name: string; fileName: string } | null>(null);

  const openModal = (url: string, name: string, fileName: string) => {
    setModalData({ url, name, fileName });
  };

  return (
    <section className="py-12 md:py-20">
      <div className="text-center mb-12">
        <h1 className="text-4xl md:text-6xl font-bold text-white mb-4">
          HexRack <span className="text-amber-500">SBC</span>
        </h1>
        <p className="text-xl text-zinc-400 mb-6">
          Modular 3D-printable honeycomb rack for cooling and mounting SBCs with a 92mm Noctua fan
        </p>
        <div className="flex items-center justify-center gap-4">
          <a
            href="https://github.com/dlepaux/hexrack-sbc"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 bg-zinc-800 hover:bg-zinc-700 text-white px-6 py-3 rounded-lg transition-colors"
          >
            <Github className="w-5 h-5" />
            View on GitHub
          </a>
          {commit && (
            <span className="text-sm text-zinc-500">
              Build: <code className="text-amber-500">{commit}</code>
            </span>
          )}
        </div>
      </div>

      {/* 3D Assembly Preview */}
      <div className="max-w-md mx-auto">
        <div className="bg-zinc-800/50 border border-zinc-700/50 rounded-xl p-4">
          {assemblies?.body ? (
            <STLViewer
              url={`${baseUrl}stl/${assemblies.body}`}
              className="h-48 md:h-64"
              onClick={() => openModal(`${baseUrl}stl/${assemblies.body}`, 'Showcase', assemblies.body)}
            />
          ) : (
            <div className="h-48 md:h-64 flex items-center justify-center text-zinc-500">
              Showcase preview not available
            </div>
          )}
          <p className="text-center text-zinc-400 mt-3 text-sm">Showcase</p>
        </div>
      </div>

      {generated && (
        <p className="text-center text-zinc-600 text-sm mt-8">
          Generated: {new Date(generated).toLocaleDateString()}
        </p>
      )}

      {modalData && (
        <STLModal
          url={modalData.url}
          name={modalData.name}
          fileName={modalData.fileName}
          onClose={() => setModalData(null)}
        />
      )}
    </section>
  );
}

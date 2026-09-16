import { Github } from 'lucide-react';

interface HeroProps {
  commit?: string;
  generated?: string;
}

export function Hero({ commit, generated }: HeroProps) {
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

      {generated && (
        <p className="text-center text-zinc-600 text-sm mt-8">
          Generated: {new Date(generated).toLocaleDateString()}
        </p>
      )}
    </section>
  );
}

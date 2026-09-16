import { Github, Heart } from 'lucide-react';

export function Footer({ commit, generated }: { commit: string; generated: string }) {
  return (
    <footer className="border-t border-zinc-800 py-8 mt-16">
      <p className="mb-4 text-xs text-zinc-600">
        Parts built from commit <code className="text-zinc-400">{commit}</code> on{' '}
        {new Date(generated).toLocaleDateString()}.
      </p>
      <div className="flex flex-col md:flex-row items-center justify-between gap-4 text-sm">
        <div className="flex items-center gap-2 text-zinc-400">
          <span>Made with</span>
          <Heart className="w-4 h-4 text-red-500 fill-red-500" />
          <span>by</span>
          <a
            href="https://david.lepaux.com"
            target="_blank"
            rel="noopener noreferrer"
            className="text-amber-500 hover:text-amber-400 transition-colors"
          >
            David Lepaux
          </a>
        </div>

        <div className="flex items-center gap-4 text-zinc-500">
          <a
            href="https://github.com/dlepaux/hexrack-sbc"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 hover:text-white transition-colors"
          >
            <Github className="w-4 h-4" />
            GitHub
          </a>
          <span className="text-zinc-700">·</span>
          <a
            href="https://github.com/dlepaux/hexrack-sbc/blob/main/license.md"
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-white transition-colors"
          >
            CC BY-NC-SA 4.0
          </a>
          <span className="text-zinc-700">·</span>
          {/* The site serves an unmodified GPL-2.0 OpenSCAD build and an OFL font; both
              licences oblige us to carry their notices where a visitor can reach them. */}
          <a
            href={`${import.meta.env.BASE_URL}licences/third-party-licences.txt`}
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-white transition-colors"
          >
            Third-party licences
          </a>
        </div>
      </div>
    </footer>
  );
}

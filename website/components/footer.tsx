import { Github, Heart } from 'lucide-react';

export function Footer() {
  return (
    <footer className="border-t border-zinc-800 py-8 mt-16">
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
        </div>
      </div>
    </footer>
  );
}

import { Loader2 } from 'lucide-react';

export function Loading() {
  return (
    <div className="min-h-screen bg-zinc-950 flex items-center justify-center">
      <div className="text-center">
        <Loader2 className="w-12 h-12 text-amber-500 animate-spin mx-auto mb-4" />
        <p className="text-zinc-400">Loading parts...</p>
      </div>
    </div>
  );
}

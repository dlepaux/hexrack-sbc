import { AlertCircle } from 'lucide-react';

interface ErrorStateProps {
  message: string;
}

export function ErrorState({ message }: ErrorStateProps) {
  return (
    <div className="min-h-screen bg-zinc-950 flex items-center justify-center">
      <div className="text-center max-w-md">
        <AlertCircle className="w-12 h-12 text-red-500 mx-auto mb-4" />
        <h2 className="text-xl font-semibold text-white mb-2">Failed to Load</h2>
        <p className="text-zinc-400 mb-4">{message}</p>
        <p className="text-sm text-zinc-500">
          STL files are generated during CI build. If you're running locally,
          run <code className="text-amber-500">./scripts/generate-stl.sh</code> first.
        </p>
      </div>
    </div>
  );
}

import { Download } from 'lucide-react';
import { useState } from 'react';
import { STLModal } from './stl-modal';
import { STLViewer } from './stl-viewer';
import { useDownloadProgress } from '../hooks/use-download-progress';
import type { Part } from '../types/manifest';

interface PartCardProps {
  part: Part;
  baseUrl: string;
}

export function PartCard({ part, baseUrl }: PartCardProps) {
  const [showModal, setShowModal] = useState(false);
  const { progress, downloadWithProgress, reset } = useDownloadProgress();
  const stlUrl = `${baseUrl}${part.file}`;

  const handleDownload = async (e: React.MouseEvent) => {
    e.stopPropagation();
    
    try {
      const blob = await downloadWithProgress(stlUrl);
      
      // Trigger browser download
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = part.file;
      link.click();
      URL.revokeObjectURL(url);
      
      // Reset progress after a short delay
      setTimeout(reset, 1000);
    } catch (error) {
      console.error('Download failed:', error);
      reset();
    }
  };

  const formatBytes = (bytes: number) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${(bytes / Math.pow(k, i)).toFixed(1)} ${sizes[i]}`;
  };

  return (
    <>
      <div className="bg-zinc-800/50 border border-zinc-700/50 rounded-xl overflow-hidden hover:border-amber-500/30 transition-all group">
        {/* 3D viewer - only renders when visible, fully unloads when off-screen */}
        <STLViewer 
          url={stlUrl} 
          className="h-48"
          onClick={() => setShowModal(true)}
        />
        <div className="p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 min-w-0">
              <h4 className="font-medium text-white truncate">{part.name}</h4>
              {part.variant && (
                <span className="shrink-0 text-[10px] uppercase tracking-wide font-semibold px-2 py-0.5 rounded-full bg-amber-500/15 text-amber-400 border border-amber-500/30">
                  {part.variant}
                </span>
              )}
            </div>
            <button
              onClick={handleDownload}
              disabled={progress.isDownloading}
              className="p-2 text-zinc-400 hover:text-amber-500 hover:bg-zinc-700/50 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              title={`Download ${part.file}`}
            >
              <Download className="w-4 h-4" />
            </button>
          </div>
          <p className="text-xs text-zinc-500 mt-1 font-mono">{part.file}</p>
          
          {/* Progress bar */}
          {progress.isDownloading && (
            <div className="mt-2 space-y-1">
              <div className="w-full bg-zinc-700 rounded-full h-2 overflow-hidden">
                <div 
                  className="bg-gradient-to-r from-amber-500 to-orange-500 h-full transition-all duration-300"
                  style={{ width: `${progress.percentage}%` }}
                />
              </div>
              <div className="flex justify-between text-xs text-zinc-400">
                <span>{progress.percentage}%</span>
                <span>{formatBytes(progress.loaded)} / {formatBytes(progress.total)}</span>
              </div>
            </div>
          )}
        </div>
      </div>

      {showModal && (
        <STLModal
          url={stlUrl}
          name={part.name}
          fileName={part.file}
          onClose={() => setShowModal(false)}
        />
      )}
    </>
  );
}

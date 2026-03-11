import { Download } from 'lucide-react';
import { useState } from 'react';
import JSZip from 'jszip';
import { saveAs } from 'file-saver';
import type { Manifest } from '../types/manifest';

interface DownloadAllButtonProps {
  manifest: Manifest;
  baseUrl: string;
}

export function DownloadAllButton({ manifest, baseUrl }: DownloadAllButtonProps) {
  const [downloadProgress, setDownloadProgress] = useState({ current: 0, total: 0 });
  const isDownloading = downloadProgress.total > 0;

  const handleDownloadAll = async () => {
    const zip = new JSZip();
    const totalParts = manifest.groups.reduce((acc, g) => acc + g.parts.length, 0);
    
    setDownloadProgress({ current: 0, total: totalParts });
    let completed = 0;

    // Create folders for each group
    for (const group of manifest.groups) {
      const folder = zip.folder(group.id);
      if (!folder) continue;

      for (const part of group.parts) {
        const response = await fetch(`${baseUrl}${part.file}`);
        const blob = await response.blob();
        folder.file(part.file, blob);
        completed++;
        setDownloadProgress({ current: completed, total: totalParts });
      }
    }

    const content = await zip.generateAsync({ type: 'blob' });
    saveAs(content, `hexrack-sbc-all-${manifest.commit}.zip`);
    
    // Reset after short delay
    setTimeout(() => setDownloadProgress({ current: 0, total: 0 }), 1000);
  };

  const totalParts = manifest.groups.reduce((acc, g) => acc + g.parts.length, 0);

  return (
    <div className="flex flex-col items-center gap-3">
      <button
        onClick={handleDownloadAll}
        disabled={isDownloading}
        className="flex items-center gap-2 bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 text-black font-semibold px-6 py-3 rounded-lg transition-all shadow-lg shadow-amber-500/20 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        <Download className="w-5 h-5" />
        {isDownloading 
          ? `Downloading ${downloadProgress.current}/${downloadProgress.total}...` 
          : `Download All (${totalParts} parts)`}
      </button>
      {isDownloading && (
        <div className="w-full max-w-xs">
          <div className="w-full bg-zinc-700 rounded-full h-2 overflow-hidden">
            <div 
              className="bg-gradient-to-r from-amber-500 to-orange-500 h-full transition-all duration-300"
              style={{ width: `${(downloadProgress.current / downloadProgress.total) * 100}%` }}
            />
          </div>
          <p className="text-xs text-zinc-400 text-center mt-1">
            {Math.round((downloadProgress.current / downloadProgress.total) * 100)}%
          </p>
        </div>
      )}
    </div>
  );
}

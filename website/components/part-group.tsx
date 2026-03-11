import { Download, Package } from 'lucide-react';
import { useState } from 'react';
import JSZip from 'jszip';
import { saveAs } from 'file-saver';
import { PartCard } from './part-card';
import type { PartGroup as PartGroupType } from '../types/manifest';

interface PartGroupProps {
  group: PartGroupType;
  baseUrl: string;
}

export function PartGroup({ group, baseUrl }: PartGroupProps) {
  const [downloadProgress, setDownloadProgress] = useState({ current: 0, total: 0 });
  const isDownloading = downloadProgress.total > 0;

  const handleDownloadAll = async () => {
    const zip = new JSZip();
    const folder = zip.folder(group.id);

    if (!folder) return;

    setDownloadProgress({ current: 0, total: group.parts.length });

    // Fetch all STL files with progress tracking
    for (let i = 0; i < group.parts.length; i++) {
      const part = group.parts[i];
      const response = await fetch(`${baseUrl}${part.file}`);
      const blob = await response.blob();
      folder.file(part.file, blob);
      setDownloadProgress({ current: i + 1, total: group.parts.length });
    }

    const content = await zip.generateAsync({ type: 'blob' });
    saveAs(content, `hexrack-sbc-${group.id}.zip`);
    
    // Reset after short delay
    setTimeout(() => setDownloadProgress({ current: 0, total: 0 }), 1000);
  };

  return (
    <section className="py-8">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h3 className="text-2xl font-bold text-white flex items-center gap-3">
            <Package className="w-6 h-6 text-amber-500" />
            {group.name}
          </h3>
          <p className="text-zinc-400 mt-1">{group.description}</p>
        </div>
        <div className="flex flex-col items-end gap-2">
          <button
            onClick={handleDownloadAll}
            disabled={isDownloading}
            className="flex items-center gap-2 bg-amber-500 hover:bg-amber-600 text-black font-medium px-4 py-2 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Download className="w-4 h-4" />
            {isDownloading 
              ? `Downloading ${downloadProgress.current}/${downloadProgress.total}...` 
              : 'Download All'}
          </button>
          {isDownloading && (
            <div className="w-full min-w-[200px] bg-zinc-700 rounded-full h-1.5 overflow-hidden">
              <div 
                className="bg-gradient-to-r from-amber-500 to-orange-500 h-full transition-all duration-300"
                style={{ width: `${(downloadProgress.current / downloadProgress.total) * 100}%` }}
              />
            </div>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {group.parts.map((part) => (
          <PartCard key={part.id} part={part} baseUrl={baseUrl} />
        ))}
      </div>
    </section>
  );
}

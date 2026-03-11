import { X, Download } from 'lucide-react';
import { STLViewer } from './stl-viewer';
import { useEffect } from 'react';
import { useDownloadProgress } from '../hooks/use-download-progress';

interface STLModalProps {
  url: string;
  name: string;
  fileName: string;
  onClose: () => void;
}

export function STLModal({ url, name, fileName, onClose }: STLModalProps) {
  const { progress, downloadWithProgress, reset } = useDownloadProgress();
  
  // Close on escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [onClose]);

  // Prevent body scroll when modal is open
  useEffect(() => {
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = 'unset';
    };
  }, []);

  const handleDownload = async () => {
    try {
      const blob = await downloadWithProgress(url);
      
      // Trigger browser download
      const blobUrl = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = blobUrl;
      link.download = fileName;
      link.click();
      URL.revokeObjectURL(blobUrl);
      
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
    <div 
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm"
      onClick={onClose}
    >
      <div 
        className="bg-zinc-900 border border-zinc-700 rounded-2xl w-full max-w-3xl max-h-[90vh] overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-zinc-800">
          <div>
            <h3 className="text-lg font-semibold text-white">{name}</h3>
            <p className="text-sm text-zinc-500 font-mono">{fileName}</p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={handleDownload}
              disabled={progress.isDownloading}
              className="flex items-center gap-2 px-4 py-2 bg-amber-500 hover:bg-amber-600 text-black font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Download className="w-4 h-4" />
              {progress.isDownloading ? `${progress.percentage}%` : 'Download'}
            </button>
            <button
              onClick={onClose}
              className="p-2 text-zinc-400 hover:text-white hover:bg-zinc-800 rounded-lg transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>
        
        {/* Progress bar */}
        {progress.isDownloading && (
          <div className="px-4 py-2 bg-zinc-800/50 border-b border-zinc-800">
            <div className="w-full bg-zinc-700 rounded-full h-2 overflow-hidden mb-2">
              <div 
                className="bg-gradient-to-r from-amber-500 to-orange-500 h-full transition-all duration-300"
                style={{ width: `${progress.percentage}%` }}
              />
            </div>
            <div className="flex justify-between text-xs text-zinc-400">
              <span>Downloading...</span>
              <span>{formatBytes(progress.loaded)} / {formatBytes(progress.total)}</span>
            </div>
          </div>
        )}
        
        {/* 3D Viewer */}
        <div className="h-[60vh]">
          <STLViewer url={url} className="h-full" autoRotate={true} />
        </div>
        
        {/* Footer hint */}
        <div className="p-3 border-t border-zinc-800 text-center text-xs text-zinc-500">
          Drag to rotate • Scroll to zoom • Press ESC to close
        </div>
      </div>
    </div>
  );
}

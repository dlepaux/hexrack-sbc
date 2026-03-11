import { useState, useCallback } from 'react';

export interface DownloadProgress {
  loaded: number;
  total: number;
  percentage: number;
  isDownloading: boolean;
}

export function useDownloadProgress() {
  const [progress, setProgress] = useState<DownloadProgress>({
    loaded: 0,
    total: 0,
    percentage: 0,
    isDownloading: false,
  });

  const downloadWithProgress = useCallback(async (url: string): Promise<Blob> => {
    setProgress({ loaded: 0, total: 0, percentage: 0, isDownloading: true });

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Download failed: ${response.statusText}`);
    }

    const contentLength = response.headers.get('content-length');
    const total = contentLength ? parseInt(contentLength, 10) : 0;

    if (!response.body) {
      throw new Error('Response body is null');
    }

    const reader = response.body.getReader();
    const chunks: Uint8Array[] = [];
    let loaded = 0;

    while (true) {
      const { done, value } = await reader.read();
      
      if (done) break;
      
      chunks.push(value);
      loaded += value.length;
      
      const percentage = total > 0 ? Math.round((loaded / total) * 100) : 0;
      
      setProgress({
        loaded,
        total,
        percentage,
        isDownloading: true,
      });
    }

    setProgress((prev) => ({ ...prev, isDownloading: false }));

    // Combine chunks into a single blob
    const blob = new Blob(chunks as BlobPart[]);
    return blob;
  }, []);

  const reset = useCallback(() => {
    setProgress({ loaded: 0, total: 0, percentage: 0, isDownloading: false });
  }, []);

  return { progress, downloadWithProgress, reset };
}

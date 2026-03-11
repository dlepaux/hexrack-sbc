import { useRef, useState, useMemo, useEffect } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls, Center, PerspectiveCamera } from '@react-three/drei';
import { STLLoader } from 'three/examples/jsm/loaders/STLLoader.js';
import * as THREE from 'three';
import { ErrorBoundary } from 'react-error-boundary';

// Custom hook to load STL with progress tracking per-instance
function useSTLWithProgress(url: string, onProgress?: (progress: { loaded: number; total: number }) => void) {
  const [geometry, setGeometry] = useState<THREE.BufferGeometry | null>(null);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const loader = new STLLoader();
    
    loader.load(
      url,
      (loadedGeometry) => {
        setGeometry(loadedGeometry);
        setError(null);
      },
      (progressEvent) => {
        if (progressEvent.lengthComputable) {
          onProgress?.({ loaded: progressEvent.loaded, total: progressEvent.total });
        }
      },
      (err) => {
        console.error('Failed to load STL:', err);
        setError(err instanceof Error ? err : new Error('Failed to load STL'));
      }
    );

    return () => {
      // Cleanup geometry on unmount
      if (geometry) {
        geometry.dispose();
      }
    };
  }, [url]); // Only reload if URL changes

  return { geometry, error };
}

interface STLModelProps {
  url: string;
  autoRotate?: boolean;
  onProgress?: (progress: { loaded: number; total: number }) => void;
  onLoaded?: () => void;
}

function STLModel({ url, autoRotate = true, onProgress, onLoaded }: STLModelProps) {
  const { geometry, error } = useSTLWithProgress(url, onProgress);
  const meshRef = useRef<THREE.Mesh>(null);
  const [hovered, setHovered] = useState(false);

  useEffect(() => {
    if (geometry) {
      onLoaded?.();
    }
  }, [geometry, onLoaded]);

  useFrame((_, delta) => {
    if (meshRef.current && autoRotate && !hovered) {
      meshRef.current.rotation.z += delta * 0.3;
    }
  });

  // Clone and process geometry - memoize to avoid recreating on each render
  const { processedGeometry, scale } = useMemo(() => {
    if (!geometry) return { processedGeometry: null, scale: 1 };
    const cloned = geometry.clone();
    cloned.center();
    cloned.computeBoundingBox();
    const box = cloned.boundingBox!;
    const size = new THREE.Vector3();
    box.getSize(size);
    const maxDim = Math.max(size.x, size.y, size.z);
    return {
      processedGeometry: cloned,
      scale: 2 / maxDim
    };
  }, [geometry]);

  if (error) {
    return null;
  }

  if (!processedGeometry) {
    return <LoadingCube />;
  }

  return (
    <mesh
      ref={meshRef}
      geometry={processedGeometry}
      scale={[scale, scale, scale]}
      rotation={[-Math.PI / 2, 0, 0]}
      onPointerOver={() => setHovered(true)}
      onPointerOut={() => setHovered(false)}
    >
      <meshStandardMaterial
        color={hovered ? '#f59e0b' : '#a1a1aa'}
        metalness={0.3}
        roughness={0.6}
      />
    </mesh>
  );
}

interface STLViewerProps {
  url: string;
  className?: string;
  autoRotate?: boolean;
  onClick?: () => void;
}

function ErrorFallback() {
  return (
    <div className="flex items-center justify-center h-full text-zinc-500 text-sm">
      Failed to load 3D model
    </div>
  );
}

function LoadingCube() {
  const meshRef = useRef<THREE.Mesh>(null);
  
  useFrame((_, delta) => {
    if (meshRef.current) {
      meshRef.current.rotation.x += delta;
      meshRef.current.rotation.y += delta * 0.5;
    }
  });

  return (
    <mesh ref={meshRef}>
      <boxGeometry args={[0.5, 0.5, 0.5]} />
      <meshStandardMaterial color="#f59e0b" wireframe />
    </mesh>
  );
}

interface LoadingOverlayProps {
  progress: { loaded: number; total: number } | null;
}

function LoadingOverlay({ progress }: LoadingOverlayProps) {
  const percentage = progress && progress.total > 0 
    ? Math.round((progress.loaded / progress.total) * 100) 
    : 0;

  const formatBytes = (bytes: number) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${(bytes / Math.pow(k, i)).toFixed(1)} ${sizes[i]}`;
  };

  return (
    <div className="absolute inset-0 flex items-center justify-center bg-zinc-900/80 backdrop-blur-sm z-10">
      <div className="text-center space-y-3 p-4">
        <div className="animate-pulse text-amber-500">
          <div className="w-12 h-12 mx-auto mb-2">
            <svg className="animate-spin" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </div>
        </div>
        {progress && progress.total > 0 ? (
          <>
            <div className="w-48 bg-zinc-700 rounded-full h-2 overflow-hidden">
              <div 
                className="bg-gradient-to-r from-amber-500 to-orange-500 h-full transition-all duration-300"
                style={{ width: `${percentage}%` }}
              />
            </div>
            <div className="text-xs text-zinc-400 space-y-1">
              <div className="font-semibold text-amber-500">{percentage}%</div>
              <div>{formatBytes(progress.loaded)} / {formatBytes(progress.total)}</div>
            </div>
          </>
        ) : (
          <div className="text-sm text-zinc-400">Loading model...</div>
        )}
      </div>
    </div>
  );
}

export function STLViewer({ url, className = '', autoRotate = true, onClick }: STLViewerProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [isVisible, setIsVisible] = useState(false);
  const [loadProgress, setLoadProgress] = useState<{ loaded: number; total: number } | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // Only render Canvas when element is in viewport - fully unload when not visible
  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        setIsVisible(entry.isIntersecting);
        if (entry.isIntersecting) {
          setIsLoading(true);
          setLoadProgress(null);
        }
      },
      { threshold: 0.1, rootMargin: '50px' }
    );

    if (containerRef.current) {
      observer.observe(containerRef.current);
    }

    return () => observer.disconnect();
  }, []);

  const handleProgress = (progress: { loaded: number; total: number }) => {
    setLoadProgress(progress);
  };

  const handleLoaded = () => {
    setTimeout(() => setIsLoading(false), 300);
  };

  return (
    <div 
      ref={containerRef} 
      className={`bg-zinc-900 rounded-lg overflow-hidden relative ${onClick ? 'cursor-pointer' : ''} ${className}`}
      onClick={onClick}
    >
      {isVisible ? (
        <>
          <ErrorBoundary fallback={<ErrorFallback />}>
            <Canvas
              gl={{ 
                powerPreference: 'low-power',
                antialias: true,
              }}
              frameloop="always"
            >
              <PerspectiveCamera makeDefault position={[0, 0, 4]} />
              <ambientLight intensity={0.4} />
              <directionalLight position={[10, 10, 5]} intensity={1} />
              <directionalLight position={[-10, -10, -5]} intensity={0.3} />
              <Center>
                <STLModel 
                  url={url} 
                  autoRotate={autoRotate} 
                  onProgress={handleProgress}
                  onLoaded={handleLoaded}
                />
              </Center>
              <OrbitControls
                enablePan={false}
                enableZoom={true}
                minDistance={2}
                maxDistance={10}
              />
            </Canvas>
          </ErrorBoundary>
          {isLoading && <LoadingOverlay progress={loadProgress} />}
        </>
      ) : (
        <div className="flex items-center justify-center h-full text-zinc-600">
          <div className="animate-pulse">Scroll to load...</div>
        </div>
      )}
    </div>
  );
}
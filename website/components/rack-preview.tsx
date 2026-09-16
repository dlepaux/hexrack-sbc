import { Suspense, useMemo } from 'react';
import { Canvas, useLoader } from '@react-three/fiber';
import { OrbitControls, PerspectiveCamera, useProgress } from '@react-three/drei';
import { STLLoader } from 'three/examples/jsm/loaders/STLLoader.js';
import { ErrorBoundary } from 'react-error-boundary';
import type { CellKey } from '../lib/rack';
import type { Placement, PreviewLayout } from '../lib/preview';

interface RackPreviewProps {
  layout: PreviewLayout;
  baseUrl: string;
  selected: CellKey;
}

/** The rack spans this many scene units along its longest side, whatever its size. */
const FIT = 2.1;

/**
 * One part at its place. useLoader caches by URL, so a file shared by five units is fetched
 * and parsed once, and a variant toggled back on is instant.
 * ponytail: the cache is never evicted -- bounded by the published part count, evict if
 * that ever grows past what a tab can hold.
 */
function PartMesh({ url, placement, selected }: { url: string; placement: Placement; selected: boolean }) {
  const geometry = useLoader(STLLoader, url);
  return (
    <mesh geometry={geometry} position={placement.position}>
      <meshStandardMaterial
        color={selected ? '#f59e0b' : '#a1a1aa'}
        metalness={0.25}
        roughness={0.6}
      />
    </mesh>
  );
}

function LoadingBadge() {
  const { active, loaded, total } = useProgress();
  if (!active) return null;
  return (
    <div className="pointer-events-none absolute left-3 top-3 rounded bg-zinc-950/80 px-2 py-1 font-mono text-[10px] text-zinc-400">
      loading parts {loaded}/{total}
    </div>
  );
}

/**
 * The configured rack, assembled from the very files the build sheet lists.
 *
 * Renders on demand rather than every frame: it only changes when the configuration or the
 * camera does, and a preview that idles at 60fps drains a laptop for nothing.
 */
export function RackPreview({ layout, baseUrl, selected }: RackPreviewProps) {
  const { min, max } = layout.bounds;
  const size = Math.max(max[0] - min[0], max[1] - min[1], max[2] - min[2]);
  const scale = FIT / size;
  const middle: [number, number, number] = [
    -(min[0] + max[0]) / 2,
    -(min[1] + max[1]) / 2,
    -(min[2] + max[2]) / 2,
  ];

  // A failed part should not blank the preview for good: a new file set gets a fresh try.
  const files = useMemo(() => layout.placements.map((p) => p.file).join('|'), [layout.placements]);

  return (
    <div className="relative h-64 overflow-hidden rounded-lg bg-zinc-950/60">
      <ErrorBoundary
        resetKeys={[files]}
        fallback={
          <div className="flex h-full items-center justify-center text-xs text-zinc-500">
            Preview unavailable — a part failed to load
          </div>
        }
      >
        <Canvas frameloop="demand" gl={{ powerPreference: 'low-power', antialias: true }}>
          <PerspectiveCamera makeDefault position={[1.3, 0.7, 4.6]} fov={30} />
          <ambientLight intensity={0.5} />
          <directionalLight position={[4, 6, 5]} intensity={1.1} />
          <directionalLight position={[-5, -2, -4]} intensity={0.3} />
          {/* CAD is +Z up and +Y into the case; turning -90° about X makes Z up and puts
              the face panels towards the camera. */}
          <group rotation={[-Math.PI / 2, 0, 0]} scale={scale}>
            <group position={middle}>
              {layout.placements.map((p) => (
                <Suspense key={p.key} fallback={null}>
                  <PartMesh url={`${baseUrl}${p.file}`} placement={p} selected={p.cell === selected} />
                </Suspense>
              ))}
            </group>
          </group>
          <OrbitControls makeDefault enablePan={false} minDistance={1.5} maxDistance={8} />
        </Canvas>
      </ErrorBoundary>
      <LoadingBadge />
    </div>
  );
}

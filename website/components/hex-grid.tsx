import { useMemo } from 'react';
import {
  DIRECTIONS,
  cellKey,
  centre,
  openSlots,
  parseCellKey,
  unitLabels,
  type CellKey,
  type Derived,
  type Unit,
} from '../lib/rack';

interface HexGridProps {
  units: ReadonlyMap<CellKey, Unit>;
  derived: ReadonlyMap<CellKey, Derived>;
  selected: CellKey;
  boardLabels: Record<string, string>;
  onSelect: (key: CellKey) => void;
  onAdd: (key: CellKey) => void;
  onRemove: (key: CellKey) => void;
}

/** Drawing radius in SVG units. The grid pitch derives from it, as in the CAD. */
const R = 46;
const SQ3 = Math.sqrt(3);
const PITCH = { column: 1.5 * R, row: SQ3 * R };

/**
 * Screen position. The model is +Z up (matching the CAD); SVG y grows downward, so z
 * is negated exactly here and nowhere else.
 */
function screen(key: CellKey) {
  const { x, z } = centre(parseCellKey(key), PITCH);
  return { x, y: -z };
}

function hexPath(cx: number, cy: number, scale = 1): string {
  let d = '';
  for (let i = 0; i < 6; i++) {
    const a = (Math.PI / 180) * (60 * i);
    d += `${i ? 'L' : 'M'}${(cx + R * scale * Math.cos(a)).toFixed(2)} ${(cy + R * scale * Math.sin(a)).toFixed(2)}`;
  }
  return `${d}Z`;
}

function corner(cx: number, cy: number, i: number): [number, number] {
  const a = (Math.PI / 180) * (60 * i);
  return [cx + R * Math.cos(a), cy + R * Math.sin(a)];
}

/**
 * Which drawn edge belongs to which direction. Corners sit at 0,60,…,300°, so edge i
 * spans corners i and i+1 and its midpoint points at 30 + 60i degrees — clockwise on
 * screen because y is flipped.
 */
const EDGE_INDEX: Record<string, number> = {
  'bottom-right': 0,
  bottom: 1,
  'bottom-left': 2,
  'top-left': 3,
  top: 4,
  'top-right': 5,
};

export function HexGrid({
  units,
  derived,
  selected,
  boardLabels,
  onSelect,
  onAdd,
  onRemove,
}: HexGridProps) {
  const labels = useMemo(() => unitLabels(units, PITCH), [units]);
  const slots = useMemo(() => openSlots(units), [units]);

  const viewBox = useMemo(() => {
    const pts = [...units.keys(), ...slots].flatMap((k) => {
      const { x, y } = screen(k);
      return [
        [x - R, y - (SQ3 * R) / 2],
        [x + R, y + (SQ3 * R) / 2],
      ];
    });
    if (pts.length === 0) return '0 0 100 100';
    const pad = 28;
    const xs = pts.map((p) => p[0]);
    const ys = pts.map((p) => p[1]);
    const minX = Math.min(...xs) - pad;
    const minY = Math.min(...ys) - pad;
    return `${minX} ${minY} ${Math.max(...xs) + pad - minX} ${Math.max(...ys) + pad - minY}`;
  }, [units, slots]);

  return (
    <svg
      viewBox={viewBox}
      role="application"
      aria-label="Rack layout"
      className="block w-full h-[24rem] sm:h-[26rem] touch-manipulation"
    >
      {slots.map((key) => {
        const { x, y } = screen(key);
        return (
          <g
            key={`slot-${key}`}
            role="button"
            tabIndex={0}
            aria-label="Add a unit here"
            className="cursor-pointer group focus:outline-none"
            onClick={() => onAdd(key)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                onAdd(key);
              }
            }}
          >
            <path
              d={hexPath(x, y, 0.9)}
              className="fill-transparent stroke-zinc-700 group-hover:fill-amber-500/10 group-hover:stroke-amber-500 group-focus-visible:stroke-amber-400"
              strokeWidth={1.5}
              strokeDasharray="4 5"
            />
            <path
              d={`M${x - 9} ${y}h18M${x} ${y - 9}v18`}
              className="stroke-zinc-600 group-hover:stroke-amber-500"
              strokeWidth={2}
              strokeLinecap="round"
            />
          </g>
        );
      })}

      {[...units.entries()].map(([key, unit]) => {
        const { x, y } = screen(key);
        const d = derived.get(key);
        const isSel = key === selected;
        const label = labels.get(key) ?? '?';

        return (
          <g key={`unit-${key}`}>
            {DIRECTIONS.filter((dir) =>
              units.has(cellKey({ q: parseCellKey(key).q + dir.dq, r: parseCellKey(key).r + dir.dr })),
            ).map((dir) => {
              const i = EDGE_INDEX[dir.face];
              const [ax, ay] = corner(x, y, i);
              const [bx, by] = corner(x, y, (i + 1) % 6);
              const mx = (ax + bx) / 2;
              const my = (ay + by) / 2;
              const t = 0.44;
              return (
                <line
                  key={dir.face}
                  x1={mx + (ax - mx) * t}
                  y1={my + (ay - my) * t}
                  x2={mx + (bx - mx) * t}
                  y2={my + (by - my) * t}
                  strokeWidth={5}
                  strokeLinecap="round"
                  className={dir.gender === 'male' ? 'stroke-amber-500' : 'stroke-cyan-400/80'}
                />
              );
            })}

            <g
              role="button"
              tabIndex={0}
              aria-label={`Unit ${label}, ${boardLabels[unit.board] ?? unit.board}${
                d ? `, rails ${d.male.join(' ') || 'none'}, grooves ${d.female.join(' ') || 'none'}` : ''
              }`}
              aria-pressed={isSel}
              className="cursor-pointer focus:outline-none"
              onClick={() => onSelect(key)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault();
                  onSelect(key);
                }
              }}
            >
              <path
                d={hexPath(x, y, 0.9)}
                className={
                  isSel
                    ? 'fill-amber-500/15 stroke-amber-500'
                    : 'fill-zinc-900 stroke-zinc-600 hover:stroke-amber-600'
                }
                strokeWidth={isSel ? 2.6 : 1.7}
              />
              <text
                x={x}
                y={y - 1}
                textAnchor="middle"
                className="fill-zinc-100 text-[15px] font-bold pointer-events-none"
              >
                {label}
              </text>
              <text
                x={x}
                y={y + 14}
                textAnchor="middle"
                className="fill-zinc-500 text-[9px] font-mono tracking-wide pointer-events-none"
              >
                {(boardLabels[unit.board] ?? unit.board).toUpperCase()}
              </text>
              {d?.feet && (
                <path
                  d={`M${x - 13} ${y + 26}h26`}
                  className="stroke-zinc-500"
                  strokeWidth={1.5}
                  strokeDasharray="2 3"
                />
              )}
            </g>

            {units.size > 1 && (
              <g
                role="button"
                tabIndex={0}
                aria-label={`Remove unit ${label}`}
                className="cursor-pointer group focus:outline-none"
                onClick={(e) => {
                  e.stopPropagation();
                  onRemove(key);
                }}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    e.stopPropagation();
                    onRemove(key);
                  }
                }}
              >
                <circle
                  cx={x + R * 0.62}
                  cy={y - R * 0.52}
                  r={9}
                  className="fill-zinc-800 stroke-zinc-600 group-hover:fill-red-500/20 group-hover:stroke-red-400"
                />
                <path
                  d={`M${x + R * 0.62 - 3.5} ${y - R * 0.52 - 3.5}l7 7M${x + R * 0.62 + 3.5} ${y - R * 0.52 - 3.5}l-7 7`}
                  className="stroke-zinc-400 group-hover:stroke-red-400"
                  strokeWidth={1.8}
                  strokeLinecap="round"
                />
              </g>
            )}
          </g>
        );
      })}
    </svg>
  );
}

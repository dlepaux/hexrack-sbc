import { Github } from 'lucide-react';
import type { Layout } from '../types/manifest';

interface HeroProps {
  layout: Layout;
}

type Pt = [number, number];

/** A label for a dimension: one decimal, trailing zero dropped, as a drawing would. */
const dim = (mm: number) => String(Number(mm.toFixed(1)));

/** Flat-top hexagon, screen coordinates (y down). */
const hexPoints = ([cx, cy]: Pt, r: number) =>
  Array.from({ length: 6 }, (_, i) => {
    const a = (Math.PI / 3) * i;
    return `${(cx + r * Math.cos(a)).toFixed(2)},${(cy + r * Math.sin(a)).toFixed(2)}`;
  }).join(' ');

/**
 * The dovetail on the face two cells share: centred between them, across the line that
 * joins their centres, as wide as the real rail.
 */
function joint(a: Pt, b: Pt, width: number) {
  const m: Pt = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
  const len = Math.hypot(b[0] - a[0], b[1] - a[1]);
  const u: Pt = [-(b[1] - a[1]) / len, (b[0] - a[0]) / len];
  return { x1: m[0] - (u[0] * width) / 2, y1: m[1] - (u[1] * width) / 2, x2: m[0] + (u[0] * width) / 2, y2: m[1] + (u[1] * width) / 2 };
}

const CALLOUTS = [
  { title: 'Printed dovetails', body: 'Cells slide together. No screws between them.' },
  { title: '92 mm Noctua fan', body: 'One per cell, behind a removable dust filter.' },
  { title: 'Sliding foot', body: 'Holds up a raised cell and slides in the same way.' },
];

/**
 * A front elevation of a real three-cell rack, drawn to the manifest's own dimensions --
 * the numbers on it are the numbers the CAD exported, not illustration.
 */
function RackDrawing({ layout, callouts, className }: HeroProps & { callouts: boolean; className: string }) {
  const r = layout.hex.pointToPoint / 2;
  const h = layout.hex.flatToFlat;
  const drop = layout.feet.drop;
  const col = layout.gridPitch.column;
  const wall = 5 / Math.cos(Math.PI / 6);
  const floor = h / 2;

  const a: Pt = [0, 0];
  const b: Pt = [0, -h];
  const c: Pt = [col, -h / 2];
  const cells = [a, b, c];
  const foot = `${col - r / 2},0 ${col + r / 2},0 ${col},${drop}`;
  const joints = [joint(a, b, 10), joint(a, c, 10), joint(b, c, 10), joint(c, [col, h / 2], 10)];

  const fanTarget: Pt = [c[0] + 46 * Math.cos(-Math.PI / 6), c[1] + 46 * Math.sin(-Math.PI / 6)];
  const bc = joint(b, c, 0);
  const textX = col + r + 42;

  const line = 'stroke-zinc-400';
  const faint = 'stroke-zinc-700';
  const note = 'fill-zinc-500 text-[9px] [font-stretch:87.5%] tabular-nums';

  return (
    <svg
      viewBox={`${-r - 42} ${-1.5 * h - 34} ${2 * r + col + (callouts ? 250 : 64)} ${1.5 * h + floor + 58}`}
      role="img"
      aria-label={`Front view of a three-cell HexRack: two cells stacked, a third raised half a cell and standing on a triangle foot. Each cell is ${dim(2 * r)} mm wide and ${dim(h)} mm tall.`}
      className={`h-auto w-full overflow-visible ${className}`}
      fill="none"
    >
      {/* Floor, hatched as a ground line */}
      <g className="appear">
        <line x1={-r - 20} y1={floor} x2={col + r + 20} y2={floor} className={line} strokeWidth={0.8} />
        {Array.from({ length: 34 }, (_, i) => {
          const x = -r - 16 + i * 9;
          return <line key={i} x1={x} y1={floor + 1} x2={x - 5} y2={floor + 6} className={faint} strokeWidth={0.6} />;
        })}
      </g>

      {cells.map((p, i) => (
        <g key={i}>
          <polygon
            points={hexPoints(p, r)}
            pathLength={1}
            className={`trace ${line}`}
            strokeWidth={1.4}
            strokeLinejoin="round"
            style={{ animationDelay: `${i * 0.18}s` }}
          />
          <g className="appear">
            <polygon points={hexPoints(p, r - wall)} className={faint} strokeWidth={0.7} />
            <circle cx={p[0]} cy={p[1]} r={46} className={faint} strokeWidth={0.7} />
            {/* Centre lines, in the long-short dash of a drafting chain line */}
            <path
              d={`M${p[0] - 54} ${p[1]}h108M${p[0]} ${p[1] - 54}v108`}
              className={faint}
              strokeWidth={0.5}
              strokeDasharray="10 2.5 2 2.5"
            />
          </g>
        </g>
      ))}

      <polygon
        points={foot}
        pathLength={1}
        className={`trace ${line} fill-zinc-800/50`}
        strokeWidth={1.4}
        strokeLinejoin="round"
        style={{ animationDelay: '0.54s' }}
      />

      <g className="appear">
        {joints.map((j, i) => (
          <line key={i} {...j} className="stroke-amber-500" strokeWidth={3.2} strokeLinecap="round" />
        ))}
      </g>

      {/* Dimensions */}
      <g className="appear">
        {/* Width, above the top cell, between its side vertices */}
        <path d={`M${-r} ${-h - 4}V${-1.5 * h - 20}M${r} ${-h - 4}V${-1.5 * h - 20}`} className={faint} strokeWidth={0.5} />
        <path d={`M${-r} ${-1.5 * h - 16}H${r}`} className={line} strokeWidth={0.6} />
        <path d={`M${-r - 2} ${-1.5 * h - 14}l4 -4M${r - 2} ${-1.5 * h - 14}l4 -4`} className={line} strokeWidth={0.8} />
        <text x={0} y={-1.5 * h - 20} textAnchor="middle" className={note}>
          {dim(2 * r)}
        </text>

        {/* Height, left of the bottom cell, between its flats */}
        <path d={`M${-r / 2 - 4} ${-h / 2}H${-r - 20}M${-r / 2 - 4} ${h / 2}H${-r - 20}`} className={faint} strokeWidth={0.5} />
        <path d={`M${-r - 16} ${-h / 2}V${h / 2}`} className={line} strokeWidth={0.6} />
        <path d={`M${-r - 18} ${-h / 2 + 2}l4 -4M${-r - 18} ${h / 2 + 2}l4 -4`} className={line} strokeWidth={0.8} />
        <text x={-r - 20} y={0} textAnchor="middle" transform={`rotate(-90 ${-r - 20} 0)`} className={note}>
          {dim(h)}
        </text>

        {/* The foot's drop, right of it */}
        <path d={`M${col + r / 2 + 4} 0H${col + r / 2 + 34}`} className={faint} strokeWidth={0.5} />
        <path d={`M${col + r / 2 + 30} 0V${drop}`} className={line} strokeWidth={0.6} />
        <path d={`M${col + r / 2 + 28} 2l4 -4M${col + r / 2 + 28} ${drop + 2}l4 -4`} className={line} strokeWidth={0.8} />
        <text x={col + r / 2 + 34} y={drop / 2 + 2.5} className={note}>
          {dim(drop)}
        </text>
      </g>

      {/* Callouts. Too small to read on a phone, where the list under the drawing takes over
          and the drawing drops the column they need. */}
      {callouts && (
      <g className="appear">
        {[
          { at: [bc.x1, bc.y1] as Pt, y: -1.5 * h + 6 },
          { at: fanTarget, y: -h / 2 - 20 },
          { at: [col, drop * 0.45] as Pt, y: drop - 8 },
        ].map((co, i) => (
          <g key={i}>
            <circle cx={co.at[0]} cy={co.at[1]} r={1.8} className="fill-amber-500" />
            <path d={`M${co.at[0]} ${co.at[1]}L${textX - 14} ${co.y}H${textX - 4}`} className="stroke-zinc-500" strokeWidth={0.6} />
            <text x={textX} y={co.y - 2} className="fill-zinc-100 text-[10px] font-semibold">
              {CALLOUTS[i].title}
            </text>
            <text x={textX} y={co.y + 10} className="fill-zinc-400 text-[8.5px]">
              {CALLOUTS[i].body}
            </text>
          </g>
        ))}
      </g>
      )}
    </svg>
  );
}

export function Hero({ layout }: HeroProps) {
  return (
    <header className="pb-16 pt-8 md:pb-24">
      <nav className="flex items-center justify-between">
        <span className="text-lg font-bold tracking-tight [font-stretch:125%]">HexRack SBC</span>
        <a
          href="https://github.com/dlepaux/hexrack-sbc"
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-2 rounded-md px-2 py-1 text-sm text-zinc-400 transition-colors hover:text-zinc-100 focus-visible:outline-2 focus-visible:outline-amber-500"
        >
          <Github className="h-4 w-4" />
          GitHub
        </a>
      </nav>

      <div className="mt-14 grid items-center gap-12 md:mt-20 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.15fr)]">
        <div>
          <h1 className="text-[clamp(2.1rem,3.6vw,3.35rem)] font-bold leading-[1.02] tracking-[-0.02em] text-zinc-50 [font-stretch:125%]">
            Rack your single-board computers in a honeycomb you print yourself
          </h1>
          <p className="mt-6 max-w-[34rem] text-lg leading-relaxed text-zinc-400">
            Each Raspberry Pi 5 or Rock 5B+ gets its own hexagonal cell, cooled by a 92 mm Noctua
            fan. Cells slide together on printed dovetails, so the rack grows one cell at a time.
          </p>
          <div className="mt-9 flex flex-wrap items-center gap-3">
            <a
              href="#configure"
              className="rounded-lg bg-amber-500 px-5 py-3 font-semibold text-zinc-950 transition-colors hover:bg-amber-400 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-300"
            >
              Configure your rack
            </a>
            <a
              href="https://github.com/dlepaux/hexrack-sbc"
              target="_blank"
              rel="noopener noreferrer"
              className="rounded-lg border border-zinc-800 px-5 py-3 font-medium text-zinc-300 transition-colors hover:border-zinc-600 hover:text-zinc-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-500"
            >
              Read the OpenSCAD source
            </a>
          </div>
          <p className="mt-6 text-sm text-zinc-500">
            Free for personal use under CC BY-NC-SA 4.0. Every part fits a 180 mm build volume.
          </p>
        </div>

        <div>
          <RackDrawing layout={layout} callouts className="hidden sm:block" />
          <RackDrawing layout={layout} callouts={false} className="mx-auto max-w-sm sm:hidden" />
          <dl className="mt-6 space-y-3 sm:hidden">
            {CALLOUTS.map((c) => (
              <div key={c.title}>
                <dt className="font-semibold text-zinc-100">{c.title}</dt>
                <dd className="text-sm text-zinc-400">{c.body}</dd>
              </div>
            ))}
          </dl>
        </div>
      </div>
    </header>
  );
}

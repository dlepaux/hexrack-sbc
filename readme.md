# HexRack SBC

Modular 3D-printable honeycomb rack for cooling and mounting SBCs with a 92mm Noctua fan.

A stackable, parametric enclosure system designed in OpenSCAD. Each unit houses one SBC with board-specific back panels and connector cutouts. Features hexagonal shell design with voronoi ventilation patterns, dovetail rail system, and silent Noctua cooling.

## Supported Boards

- Rock 5B+
- Raspberry Pi 5 + Pironman 5 Max

## Project Structure

```
cad/                   OpenSCAD parametric design
  config.scad            Master configuration (dimensions, presets, tolerances)
  body.scad              Main entry point for rendering
  sections/body/         Body modules (face, fan, back, feet)
  components/            Reusable parts (rails, snap-fits, dovetails)
  lib/                   Helpers (shapes, honeycomb, screws, brackets)
  assets/                STL/SVG assets (fan model, voronoi pattern)
  SBC_Model_Framework/   Git submodule with precise SBC 3D models
website/                React + Three.js STL viewer and download portal
scripts/                STL generation pipeline
```

## Quick Start

### View & Download Parts

Visit the [live website](https://dlepaux.github.io/hexrack-sbc/) to preview 3D models and download STL files.

### Build Locally

```bash
# Install website dependencies
npm install

# Fetch the OpenSCAD WebAssembly runtime the configurator engraves with (~3MB, once)
./scripts/fetch-openscad-wasm.sh

# Dev server
npm run dev

# Generate STL files (requires OpenSCAD nightly)
chmod +x scripts/generate-stl.sh
./scripts/generate-stl.sh --local
```

### Requirements

- [OpenSCAD](https://openscad.org/downloads.html) (nightly recommended for Manifold backend)
- [Node.js](https://nodejs.org/) 22+ (for website)

## Hardware

Per unit:

- **Fan**: Noctua NF-A9 PWM (92mm, 5V) — ×1, mounted with M5
- **M4×50 + M4 nut traps**: the face → dust filter → fan → back stack
- **M3×10**: back panel joins
- **M2.5×4 + heat-set inserts**: SBC standoffs
- **Filament**: PLA, PETG (preferred)

Units joined into a rack need no extra fasteners — the intercase dovetail is entirely
printed. The [configurator](https://dlepaux.github.io/hexrack-sbc/) totals the hardware
for a whole rack.

## How It Works

Each unit is one SBC enclosure. The body is split into printable sections that snap together:

1. **Face** - Front panel with voronoi ventilation pattern
2. **Dust Filter** - Removable filter compartment, optionally engraved (see below)
3. **Fan Section** - 92mm Noctua mount with airflow channel
4. **Back Top** - Upper shell half with dovetail rails and diamond stacking keys for vertical/horizontal alignment
5. **Back Bottom** - Lower shell half with SBC mounting supports, screw pillars, and board-specific standoffs
6. **Feet** - Tree trunk-shaped base with diamond key that locks into the back bottom

The back panels are generated per-board configuration, so each unit gets precise mounting holes and connector openings for its specific SBC. Units stack on top of each other.

### Engraved labels

Each unit's dust filter can carry two engraved lines — a hostname, a rack position — cut
into the flat band between its two hexagons, which is the one outward-facing surface on
the assembled case that prints as a top face.

A label is per-unit, so it cannot be pre-built: CI publishes only the blank filter. The
configurator instead runs **real OpenSCAD, compiled to WebAssembly, in a Web Worker over
this repository's own `cad/` sources**, with the label passed as `-D`. That is the point
of carrying a 3MB runtime rather than doing the text in JavaScript: the mesh comes out of
the same Manifold engine and the same sources as every other published part, so an
engraved filter is the published one plus the text, not a lookalike. The browser's output
has been verified bit-identical to a native OpenSCAD render, vertex for vertex.

The runtime is fetched only when a label is actually set, so an unlabelled configuration
downloads nothing extra.

The limit on a label is a **width in millimetres, not a character count** — `dustLabelCutter()`
derives it from the hexagon band and publishes it as `manifest.labelLimit`. "NODE-01-RACK-A-XY"
and "NODE-01-RACK-ABCD" are both 17 characters and span 70.8mm and 74.1mm. Past the limit
the glyphs run off the flat and quietly stop cutting, so the field measures the real text
in the real font and the CAD asserts it again during the render.

## CI/CD

Pushing to `main` triggers GitHub Actions which:
1. Generates all STL files with OpenSCAD
2. Builds the React website
3. Deploys to GitHub Pages

## License

[CC BY-NC-SA 4.0](license.md) - David Lepaux

You are free to share and adapt this work for non-commercial purposes, with attribution and under the same license.

For commercial licensing inquiries, reach out at [david.lepaux.com](https://david.lepaux.com).

The site also serves two unmodified third-party components under their own terms: the
OpenSCAD WebAssembly build (GPL-2.0 with the CGAL linking exception) and Liberation Sans
Bold (SIL OFL 1.1). Notices and licence texts are in [`public/licences/`](public/licences/).

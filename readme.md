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
  sections/body/         Body modules (face, fan, back, feet, top-supports)
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

- **Fan**: Noctua NF-A9 PWM (92mm, 5V)
- **Screws**: M3-10 (body), M3-16 (face/dust filter), M5 (fan)
- **Filament**: PLA, PETG (preferred)

## How It Works

Each unit is one SBC enclosure. The body is split into printable sections that snap together:

1. **Face** - Front panel with voronoi ventilation pattern
2. **Dust Filter** - Removable filter compartment
3. **Fan Section** - 92mm Noctua mount with airflow channel
4. **Back Top** - Upper shell half with dovetail rails and diamond stacking keys for vertical/horizontal alignment
5. **Back Bottom** - Lower shell half with SBC mounting supports, screw pillars, and board-specific standoffs
6. **Feet** - Tree trunk-shaped base with diamond key that locks into the back bottom

The back panels are generated per-board configuration, so each unit gets precise mounting holes and connector openings for its specific SBC. Units stack on top of each other.

## CI/CD

Pushing to `main` triggers GitHub Actions which:
1. Generates all STL files with OpenSCAD
2. Builds the React website
3. Deploys to GitHub Pages

## License

[CC BY-NC-SA 4.0](LICENSE) - David Lepaux

You are free to share and adapt this work for non-commercial purposes, with attribution and under the same license.

For commercial licensing inquiries, reach out at [david.lepaux.com](https://david.lepaux.com).

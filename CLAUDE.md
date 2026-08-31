# hexrack-sbc - 3D-Printable SBC Rack

Modular 3D-printable honeycomb rack for cooling and mounting SBCs with a 92mm Noctua fan. Designed in OpenSCAD with a React + Three.js website for STL preview and download.

## Supported Boards

- Rock 5B+
- Raspberry Pi 5 + Pironman 5 Max

## Structure

```
cad/                   OpenSCAD parametric design
  config.scad            Master configuration
  body.scad              Main entry point
  sections/body/         Body modules (face, fan, back, feet, top-supports)
  components/            Reusable parts (rails, snap-fits, dovetails)
  lib/                   Helpers (shapes, honeycomb, screws, brackets)
  assets/                STL/SVG assets
  SBC_Model_Framework/   Git submodule — precise SBC 3D models
website/                React + Three.js STL viewer and download portal
scripts/                STL generation pipeline
```

## Commands

```bash
npm install             # Website dependencies
npm run dev             # Dev server
./scripts/generate-stl.sh --local  # Generate STL files (requires OpenSCAD nightly)
./scripts/test-variant-matrix.sh   # Test the STL variant matrix (no OpenSCAD needed)
./scripts/test-front-circle.sh     # Face panel front-circle geometry (requires OpenSCAD)
./scripts/test-fan-wire-slots.sh   # Fan web cable-notch geometry (requires OpenSCAD)
./scripts/test-vent-patterns.sh    # Face panel vent pattern modes (requires OpenSCAD)
```

## CI/CD (GitHub Actions)

Push to `main` → generate STL files → build React website → deploy to GitHub Pages.

## Conventions

- OpenSCAD (nightly, Manifold backend) for CAD
- Node.js 22+ for website
- React, Three.js, TypeScript

#!/usr/bin/env python3
"""Generate the gyroid tunnel cutter as a printable-scale STL asset.

WHY AN ASSET. The gyroid is an implicit surface, and OpenSCAD cannot mesh one. The
previous approach solved a 2D slice in closed form and stacked the slices as prisms,
which works but is bounded by real mathematics: the closed-form strand exists only
while |sin(phase)| <= sqrt(1/2), so a panel can never sweep more than 90 degrees of
lattice -- a quarter turn, at any thickness or period. A tunnel that turns needs a
full 360, so it needs a real isosurface.

Meshing it once, offline, and importing the result is the same trick the project
already uses for assets/voronoi_svg.svg and assets/noctua-92.stl. CI needs no extra
tooling because the asset is committed.

THE SURFACE. The gyroid is

    G(x, y, z) = sin x cos y + sin y cos z + sin z cos x

with one period every 2*pi. The solid emitted here is {G > level}: one of the two
interpenetrating labyrinths. Subtracting it from a panel leaves the other labyrinth as
material, so the holes are continuous curved tunnels and the remaining wall is a single
connected network. At level 0 the split is even.

OUTPUT SPACE. Normalised so one period is exactly 1.0 unit, letting OpenSCAD pick the
physical cell size with a single scale(). The mesh is a closed solid: the isosurface is
capped at the box walls so it can be differenced, and neighbouring copies fuse across
those coincident caps when tiled.

Usage:
    generate-gyroid-asset.py OUT.stl [--periods 20x18] [--depth 1.4]
                                     [--samples 8] [--level 0.0]
"""

import argparse
import struct
import sys

import numpy as np
from skimage import measure

TAU = 2.0 * np.pi


def gyroid_field(shape_periods, depth_periods, samples):
    """Sample G over the box, in units where one period is 1.0."""
    nx = int(round(shape_periods[0] * samples)) + 1
    nz = int(round(shape_periods[1] * samples)) + 1
    ny = int(round(depth_periods * samples)) + 1

    x = np.linspace(0.0, shape_periods[0], nx)
    y = np.linspace(0.0, depth_periods, ny)
    z = np.linspace(0.0, shape_periods[1], nz)

    X, Y, Z = np.meshgrid(x * TAU, y * TAU, z * TAU, indexing="ij")
    field = (np.sin(X) * np.cos(Y)
             + np.sin(Y) * np.cos(Z)
             + np.sin(Z) * np.cos(X))
    return field, (x, y, z)


def closed_solid(field, level):
    """Pad the field below `level` on every side so the isosurface closes into a solid.

    Without this the mesh is an open sheet: marching cubes only emits where the field
    crosses the level, so the region simply runs off the edge of the array and the
    result is not a solid anything can be subtracted from.
    """
    return np.pad(field, 1, mode="constant", constant_values=level - 10.0)


def write_binary_stl(path, verts, faces):
    with open(path, "wb") as handle:
        handle.write(b"hexrack gyroid tunnel cutter, normalised to one period = 1.0".ljust(80, b"\0"))
        handle.write(struct.pack("<I", len(faces)))
        tri = verts[faces]                                   # (n, 3, 3)
        normals = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        lengths = np.linalg.norm(normals, axis=1, keepdims=True)
        normals = np.divide(normals, lengths, out=np.zeros_like(normals),
                            where=lengths > 0)
        record = np.zeros((len(faces), 12), dtype="<f4")
        record[:, 0:3] = normals
        record[:, 3:12] = tri.reshape(len(faces), 9)
        blob = bytearray()
        for row in record:
            blob += row.tobytes() + b"\0\0"
        handle.write(bytes(blob))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out")
    ap.add_argument("--periods", default="20x18",
                    help="cells across X and Z (default 20x18)")
    ap.add_argument("--depth", type=float, default=1.4,
                    help="cells through Y; 1.0 is one full tunnel turn (default 1.4)")
    ap.add_argument("--samples", type=int, default=8,
                    help="grid samples per period; sets mesh resolution (default 8)")
    ap.add_argument("--level", type=float, default=0.0,
                    help="isosurface level; >0 thins the tunnels (default 0.0)")
    args = ap.parse_args()

    try:
        wide, tall = (float(v) for v in args.periods.lower().split("x"))
    except ValueError:
        print(f"bad --periods {args.periods!r}, expected WIDExTALL", file=sys.stderr)
        return 2

    field, (x, y, z) = gyroid_field((wide, tall), args.depth, args.samples)
    padded = closed_solid(field, args.level)

    step = 1.0 / args.samples
    verts, faces, _normals, _values = measure.marching_cubes(
        padded, level=args.level, spacing=(step, step, step))
    # Undo the one-voxel pad so the mesh starts at the origin.
    verts -= step

    write_binary_stl(args.out, verts, faces)

    print(f"  periods   {wide:g} x {tall:g} across, {args.depth:g} deep")
    print(f"  samples   {args.samples}/period  (level {args.level:g})")
    print(f"  vertices  {len(verts)}")
    print(f"  triangles {len(faces)}")
    print(f"  extent    {verts.max(axis=0) - verts.min(axis=0)}")
    print(f"  wrote     {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

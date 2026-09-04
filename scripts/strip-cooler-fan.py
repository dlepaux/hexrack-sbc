#!/usr/bin/env python3
"""Delete the Coolserver's 60mm fan from its STL, using the box set in the CAD.

WHY A SCRIPT AND NOT A difference(). The asset is an open surface -- OpenSCAD reports
"Input mesh is not closed" and Manifold conversion fails -- so subtracting a cube from it
does not remove the fan, it collapses the entire object to nothing. The cooler disappears
and the model still renders and exports cleanly. Cutting the triangles out of the file is
the only way the cube can actually do anything.

The box lives in cad/lib/naja-duo-base.scad as `naja_duo_fan_box`, in the asset's own
frame (millimetres, before the 90-degree rotation and the board placement). Set it there,
preview it in the model -- setup.scad draws it with # -- and run this once it wraps the
fan.

A triangle is removed only when ALL THREE of its vertices are inside the box. Triangles
that straddle the boundary stay, so the cut never opens a hole in something the box only
clips: it errs toward keeping material, which for a preview mesh is the safe direction.

    ./scripts/strip-cooler-fan.py            # apply, writing a .orig backup
    ./scripts/strip-cooler-fan.py --dry-run  # report what would go, change nothing
    ./scripts/strip-cooler-fan.py --restore  # put the .orig back

The measurements the rest of the project depends on (naja_duo_heatsink_above/below/size
and the two profiles) are taken from this file, so run scripts/test-board-fit.sh
afterwards -- it asserts they still match, and is what will tell you the cut moved
something it should not have.
"""

import argparse
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "cad/lib/naja-duo-base.scad")


def read_box():
    """The two corners of naja_duo_fan_box, straight from the CAD."""
    src = open(BASE).read()
    m = re.search(
        r"^naja_duo_fan_box\s*=\s*\[\s*\[([^\]]+)\]\s*,\s*\[([^\]]+)\]\s*\]", src, re.M
    )
    if not m:
        sys.exit("naja_duo_fan_box not found in cad/lib/naja-duo-base.scad")
    lo = [float(x) for x in m.group(1).split(",")]
    hi = [float(x) for x in m.group(2).split(",")]
    return lo, hi


def asset_path():
    src = open(BASE).read()
    m = re.search(r'^naja_duo_heatsink_asset\s*=\s*"([^"]+)"', src, re.M)
    if not m:
        sys.exit("naja_duo_heatsink_asset not found")
    # The constant is relative to cad/lib/, the way OpenSCAD reads it.
    return os.path.normpath(os.path.join(ROOT, "cad/lib", m.group(1)))


def scale():
    src = open(BASE).read()
    m = re.search(r"^naja_duo_heatsink_scale\s*=\s*([0-9.]+)", src, re.M)
    return float(m.group(1)) if m else 1.0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="report only")
    ap.add_argument("--restore", action="store_true", help="restore the .orig backup")
    args = ap.parse_args()

    path = asset_path()
    backup = path + ".orig"

    if args.restore:
        if not os.path.exists(backup):
            sys.exit(f"no backup at {backup}")
        os.replace(backup, path)
        print(f"restored {os.path.basename(path)} from .orig")
        return

    lo, hi = read_box()
    s = scale()
    print(f"asset : {os.path.relpath(path, ROOT)}")
    print(f"box   : X {lo[0]}..{hi[0]}  Y {lo[1]}..{hi[1]}  Z {lo[2]}..{hi[2]}  (mm, asset frame)")

    with open(path, "rb") as f:
        f.read(80)
        (count,) = struct.unpack("<I", f.read(4))
        size = os.path.getsize(path)
        if 84 + 50 * count != size:
            sys.exit("not a binary STL — run this on the committed asset, not an ASCII export")
        keep, dropped = [], 0
        for _ in range(count):
            rec = f.read(50)
            vals = struct.unpack("<12f", rec[:48])
            verts = [tuple(vals[k + i] * s for i in range(3)) for k in (3, 6, 9)]
            if all(all(lo[i] <= v[i] <= hi[i] for i in range(3)) for v in verts):
                dropped += 1
            else:
                keep.append(rec)

    pct = 100.0 * dropped / count if count else 0.0
    print(f"result: {count} triangles → {len(keep)}  (removes {dropped}, {pct:.1f}%)")

    if dropped == 0:
        print("\nNothing fell inside the box. It is in the asset's OWN frame — before the\n"
              "90-degree rotation and before the board placement — so section coordinates\n"
              "will not match. Preview it in setup.scad and move it there.")
        return

    if args.dry_run:
        print("\n--dry-run: nothing written.")
        return

    if not os.path.exists(backup):
        os.replace(path, backup)
        with open(backup, "rb") as src, open(path, "wb") as dst:
            dst.write(src.read())
        print(f"backup: {os.path.basename(backup)}")

    with open(path, "wb") as f:
        f.write(b"Coolserver LGA1700 R64 v22, 60mm fan removed".ljust(80, b"\0"))
        f.write(struct.pack("<I", len(keep)))
        for rec in keep:
            f.write(rec)

    lo3 = [1e30] * 3
    hi3 = [-1e30] * 3
    with open(path, "rb") as f:
        f.read(80)
        (n,) = struct.unpack("<I", f.read(4))
        for _ in range(n):
            v = struct.unpack("<12f", f.read(50)[:48])
            for k in (3, 6, 9):
                for i in range(3):
                    c = v[k + i] * s
                    lo3[i] = min(lo3[i], c)
                    hi3[i] = max(hi3[i], c)
    print(f"\nnew bounds (scaled): X {lo3[0]:.3f}..{hi3[0]:.3f}  "
          f"Y {lo3[1]:.3f}..{hi3[1]:.3f}  Z {lo3[2]:.3f}..{hi3[2]:.3f}")
    print(f"  naja_duo_heatsink_size  should be [{hi3[0]-lo3[0]:.3f}, {hi3[1]-lo3[1]:.3f}]")
    print(f"  naja_duo_heatsink_above should be {hi3[2]:.3f}")
    print(f"  naja_duo_heatsink_below should be {-lo3[2]:.3f}")
    print("\nUpdate those in cad/lib/naja-duo-base.scad, then run "
          "./scripts/test-board-fit.sh — it asserts them against the file.")


if __name__ == "__main__":
    main()

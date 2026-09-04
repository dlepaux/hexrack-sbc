#!/usr/bin/env bash
# ============================================================================
# TEST: board fit inside the hexagonal bore
# ============================================================================
# The Naja Duo is the reason this exists. It is 147.000 x 90.000, and the bore's
# widest internal chord is body_width - 2*wall_thickness/cos(30) = 138.45mm, so it
# only fits one way round -- long axis along the case depth -- and its heatsink then
# has to thread a fin stack 67mm tall through a hexagon that narrows above the board.
# Nothing in a render says when that stops being true: OpenSCAD will happily export a
# perfectly clean case with the board's corners buried in the wall.
#
# Two independent checks, because they fail for different reasons:
#
#   FIT      Renders cad/setup.scad's overflow view -- the board envelope MINUS the
#            bore -- and asserts it is empty. Catches a preset offset, a standoff
#            height or a case dimension that puts the board through a wall.
#
#   ASSETS   Asserts the bounding boxes of the two Naja Duo STLs still match the
#            constants in cad/lib/naja-duo-base.scad. Catches a board revision or a
#            re-exported mesh silently invalidating every number the FIT check
#            depends on. A new rev with different outline is the expected way this
#            fires -- the upstream README calls rev 1201 an untested prototype.
#
# Usage: ./scripts/test-board-fit.sh
# Requires OpenSCAD (nightly, Manifold backend).
# ============================================================================

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OPENSCAD="${OPENSCAD:-}"
if [ -z "$OPENSCAD" ]; then
    for c in openscad-nightly openscad \
             /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD; do
        if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then OPENSCAD="$c"; break; fi
    done
fi
if [ -z "$OPENSCAD" ]; then
    echo "❌ OpenSCAD not found. Set OPENSCAD=/path/to/openscad"; exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Only boards that DECLARE a measured envelope are fit-checked. rock5b+ and
# rpi5_pironman do not: nothing in this repo states how tall their components are, and
# the outline alone is not a usable stand-in for them. The Pironman proves why -- its
# natural depth of 95.83 spans a Pi5 plus an NVMe board hanging off one side and a GPIO
# riser off the other, so the solid 85 x 95.83 rectangle you would have to assume is
# both the wrong shape and, once x_offset moves it, in the wrong place. Checking it
# reports a 37.6mm collision on a design that has been printed and works.
#
# Listing them as skipped rather than quietly passing them: a green tick against a
# board this cannot actually check is worse than no tick.
BOARDS=(bitaxe_naja_duo)
SKIPPED=(rock5b+ rpi5_pironman)
fails=0

# ----------------------------------------------------------------------------
# FIT
# ----------------------------------------------------------------------------
echo "=== Fit: board envelope vs hexagonal bore ==="

for board in "${BOARDS[@]}"; do
    out="$TMP/overflow-$board.stl"
    log="$TMP/overflow-$board.log"

    # binstl is not cosmetic: the triangle count is read straight out of the binary
    # header below, and OpenSCAD's default ASCII output parses as a garbage count in
    # the hundreds of millions -- a collision that is really a pass, or vice versa.
    "$OPENSCAD" --backend=Manifold --export-format=binstl -o "$out" \
        -D "drawer_board=\"$board\"" -D 'setup_view="overflow"' \
        cad/setup.scad >"$log" 2>&1
    rc=$?

    # "Current top level object is empty" IS the pass: the board is entirely inside
    # the bore, so the difference() left nothing. OpenSCAD exits non-zero on it, so
    # the exit code alone cannot be the verdict -- but a render that died early also
    # produces no geometry, and that must NOT read as a pass. Hence: empty is a pass
    # only when nothing else went wrong.
    if grep -q "ERROR" "$log"; then
        echo "  ❌ $board: errors during render"; grep "ERROR" "$log" | sed 's/^/      /'
        fails=$((fails+1)); continue
    fi
    if grep -q "top level object is empty" "$log"; then
        echo "  ✓ $board: entirely inside the bore"
        continue
    fi
    if [ "$rc" -ne 0 ]; then
        echo "  ❌ $board: render failed (rc=$rc)"; sed 's/^/      /' "$log" | tail -5
        fails=$((fails+1)); continue
    fi

    tris=$(python3 - "$out" <<'PY'
import struct, sys
try:
    with open(sys.argv[1], "rb") as h:
        h.read(80)
        print(struct.unpack("<I", h.read(4))[0])
except Exception:
    print(-1)
PY
)
    if [ "$tris" = "0" ]; then
        echo "  ✓ $board: entirely inside the bore"
    elif [ "$tris" = "-1" ]; then
        echo "  ❌ $board: could not read $out"; fails=$((fails+1))
    else
        echo "  ❌ $board: $tris triangles OUTSIDE the bore — the board hits the case"
        python3 scripts/lib/stl-stats.py "$out" --bboxes 2>/dev/null \
            | sed 's/^/      overflow body (dx dy dz): /'
        fails=$((fails+1))
    fi
done

for board in "${SKIPPED[@]}"; do
    echo "  – $board: skipped (no measured envelope declared — outline only would be a false result)"
done

# ----------------------------------------------------------------------------
# SUPPORT CLEARANCE
# ----------------------------------------------------------------------------
# The canoe supports rise to support_mandatory_standoff_height BELOW the board, and
# the board's own underside hardware hangs down into that same gap. If the gap is
# shorter than the hardware, the printed boss and the connector want the same space --
# and both parts still render and export perfectly cleanly, because the board is only
# a preview model and is never differenced against the supports.
#
# This is exactly how the Naja Duo shipped its first draft: 10mm of standoff under a
# connector that needs 10.645mm.
echo ""
echo "=== Supports: standoff gap vs the board's underside hardware ==="

python3 - <<'PY'
import re, os, sys

root = os.getcwd()
cfg  = open(os.path.join(root, "cad/config.scad")).read()
base = open(os.path.join(root, "cad/lib/naja-duo-base.scad")).read()

def const(src, name):
    m = re.search(rf"^{name}\s*=\s*([-0-9.]+)\s*;", src, re.M)
    return float(m.group(1)) if m else None

# The preset is a flat 15-field vector; field 14 is support_mandatory_standoff_height.
m = re.search(r"preset_bitaxe_naja_duo\s*=\s*\[(.*?)\]\s*;", cfg, re.S)
if not m:
    print("  \u274c preset_bitaxe_naja_duo not found"); sys.exit(1)
fields = [f.strip() for f in m.group(1).split(",") if f.strip()]
standoff = float(fields[14])
under    = const(base, "naja_duo_underside_clearance")

ok = standoff >= under
mark = "\u2713" if ok else "\u274c"
note = "" if ok else "  <-- the canoe boss lands inside the XT30"
print(f"  {mark} bitaxe_naja_duo: {standoff:.1f}mm standoff vs {under:.3f}mm of "
      f"underside hardware{note}")
sys.exit(0 if ok else 1)
PY
support_rc=$?

# ----------------------------------------------------------------------------
# ASSETS
# ----------------------------------------------------------------------------
echo ""
echo "=== Assets: STL bounds vs the constants derived from them ==="

python3 - <<'PY'
import re, sys, os, struct

ROOT = os.getcwd()
BASE = os.path.join(ROOT, "cad/lib/naja-duo-base.scad")
src  = open(BASE).read()

def const(name):
    m = re.search(rf"^{name}\s*=\s*([-0-9.]+)\s*;", src, re.M)
    if not m:
        print(f"  ❌ {name} not found in naja-duo-base.scad"); sys.exit(1)
    return float(m.group(1))

def bbox(path, scale=1.0):
    """Bounding box of an STL, ASCII or binary.

    Format-agnostic on purpose. These assets arrived as ASCII and were converted to
    binary to commit them (every other asset in cad/assets is binary, and ASCII was
    six times the size). A reader that assumed one format silently found no vertices
    at all and reported -inf for every dimension.
    """
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3

    with open(path, "rb") as h:
        head = h.read(84)
    size = os.path.getsize(path)
    is_binary = False
    if len(head) == 84:
        (count,) = struct.unpack("<I", head[80:84])
        is_binary = (84 + 50 * count == size)

    if is_binary:
        with open(path, "rb") as h:
            h.read(84)
            for _ in range(count):
                rec = h.read(50)
                vals = struct.unpack("<12f", rec[:48])
                for k in (3, 6, 9):
                    for i in range(3):
                        v = vals[k + i] * scale
                        if v < lo[i]: lo[i] = v
                        if v > hi[i]: hi[i] = v
    else:
        with open(path, "r", errors="ignore") as h:
            for line in h:
                if "vertex" not in line:
                    continue
                p = line.split()
                for i in range(3):
                    v = float(p[i + 1]) * scale
                    if v < lo[i]: lo[i] = v
                    if v > hi[i]: hi[i] = v

    if lo[0] == float("inf"):
        raise SystemExit(f"  \u274c {path}: no vertices read")
    return lo, hi

bad = 0

def check(label, actual, expected, tol=0.01):
    global bad
    ok = abs(actual - expected) <= tol
    print(f"  {'✓' if ok else '❌'} {label}: {actual:.3f} (declared {expected:.3f})")
    if not ok: bad += 1

pcb = os.path.join(ROOT, "cad/assets/BitaxeNajaDuo.stl")
lo, hi = bbox(pcb)
check("PCB width  (naja_duo_width)",  hi[0]-lo[0], const("naja_duo_width"))
check("PCB depth  (naja_duo_depth)",  hi[1]-lo[1], const("naja_duo_depth"))
# The PCB slab's own bottom is the mesh's z=0; the underside clearance is how far the
# XT30 hangs below it, so it is the mesh's -min(z).
check("PCB underside (naja_duo_underside_clearance)",
      -lo[2], const("naja_duo_underside_clearance"))

hs = os.path.join(ROOT, "cad/assets/Coolserver LGA1700 R64 v22.stl")
s = const("naja_duo_heatsink_scale")
lo, hi = bbox(hs, s)
m = re.search(r"naja_duo_heatsink_size\s*=\s*\[\s*([-0-9.]+)\s*,\s*([-0-9.]+)", src)
check("heatsink X (naja_duo_heatsink_size[0])", hi[0]-lo[0], float(m.group(1)))
check("heatsink Y (naja_duo_heatsink_size[1])", hi[1]-lo[1], float(m.group(2)))
check("heatsink above PCB (naja_duo_heatsink_above)", hi[2], const("naja_duo_heatsink_above"))
check("heatsink below PCB (naja_duo_heatsink_below)", -lo[2], const("naja_duo_heatsink_below"))

sys.exit(1 if bad else 0)
PY
asset_rc=$?

echo ""
if [ "$fails" -eq 0 ] && [ "$asset_rc" -eq 0 ] && [ "$support_rc" -eq 0 ]; then
    echo "✅ All board fit checks passed"
    exit 0
fi
echo "❌ Board fit checks FAILED (fit: $fails, supports: $support_rc, assets: $asset_rc)"
exit 1

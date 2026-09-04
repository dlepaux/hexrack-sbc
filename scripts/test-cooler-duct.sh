#!/usr/bin/env bash
# ============================================================================
# TEST: cooler duct (fan section, bitaxe_naja_duo)
# ============================================================================
# The Naja Duo runs with the Coolserver's own 60mm fan removed, so the 92mm Noctua is
# the only fan and this duct is what gets its air onto the fin stack. Four things about
# it fail silently -- the part renders and exports perfectly cleanly in every case:
#
#   ATTACHED  The duct's inlet is deliberately SMALLER than the bore it sits in, so it
#             touches nothing on its own and is held only by the vanes. Get those wrong
#             and the fan section exports as two bodies, one of which falls out of the
#             case on the print bed.
#
#   BLEED     The bleed ring is the whole reason the inlet is undersized: it is what
#             feeds the under-board plenum. An inlet grown to the full bore closes it
#             and starves the board, while still looking like a working duct.
#
#   CLEARS    The duct passes over the FRONT of the PCB climbing to the intake. Nothing
#             in either part announces the day it stops clearing.
#
#   SCOPED    Only this board has a cooler. The duct must not appear on the others --
#             their fan section is shared and must stay the shape it always was.
#
# Usage: ./scripts/test-cooler-duct.sh
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
[ -z "$OPENSCAD" ] && { echo "❌ OpenSCAD not found. Set OPENSCAD=/path/to/openscad"; exit 1; }

STATS="$ROOT/scripts/lib/stl-stats.py"
# In-tree: snap-confined OpenSCAD cannot see the host's /tmp. Same as the other tests.
WORK="$(mktemp -d "$ROOT/.test-work.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
CHECKS=0
pass() { echo "  ✓ $1"; CHECKS=$((CHECKS + 1)); }
fail() { echo "  ✗ $1"; FAILURES=$((FAILURES + 1)); CHECKS=$((CHECKS + 1)); }

cad() {  # read a numeric constant out of the CAD, never a literal copied here
    sed -n "s/^$1 *= *\([0-9.]*\).*/\1/p" cad/config.scad | head -1
}

echo "=== Cooler duct ==="

BORE=$(cad fan_size_mode)
INLET=$(cad duct_inlet_diameter)
OUTLET=$(cad duct_outlet_size)
OUT_Z=$(cad duct_outlet_z)
LEN=$(cad duct_length)

# ---------------------------------------------------------------------------
# ATTACHED — one body, for the board that has a duct
# ---------------------------------------------------------------------------
"$OPENSCAD" --backend=Manifold --export-format=binstl -o "$WORK/fan-naja.stl" \
    -D 'drawer_board="bitaxe_naja_duo"' -D 'body_part="fan"' cad/body.scad \
    >"$WORK/fan-naja.log" 2>&1
if grep -q ERROR "$WORK/fan-naja.log"; then
    fail "fan section failed to render for bitaxe_naja_duo"
else
    read -r tris bodies <<<"$(python3 "$STATS" "$WORK/fan-naja.stl")"
    if [ "$bodies" = "1" ]; then
        pass "duct is fused to the fan section (1 body, $tris triangles)"
    else
        fail "fan section is $bodies bodies — the duct is not held by its vanes"
    fi
fi

# ---------------------------------------------------------------------------
# SCOPED — the other boards keep the fan section they always had
# ---------------------------------------------------------------------------
for board in rock5b+ rpi5_pironman; do
    "$OPENSCAD" --backend=Manifold --export-format=binstl -o "$WORK/fan-$board.stl" \
        -D "drawer_board=\"$board\"" -D 'body_part="fan"' cad/body.scad \
        >"$WORK/fan-$board.log" 2>&1
    # The REAR FACE, not the bbox depth. The section also carries its male lip tongue,
    # which protrudes ~4mm at NEGATIVE y, so its extent is ~35mm on a 31mm section and
    # comparing that to fan_depth flags every board as having a duct.
    rear=$(python3 - "$WORK/fan-$board.stl" <<'PY'
import struct, sys
with open(sys.argv[1], "rb") as h:
    h.read(80)
    (n,) = struct.unpack("<I", h.read(4))
    hi = -1e30
    for _ in range(n):
        v = struct.unpack("<12f", h.read(50)[:48])
        for k in (3, 6, 9):
            if v[k + 1] > hi: hi = v[k + 1]
print(f"{hi:.3f}")
PY
)
    fan_depth=$(cad fan_depth)
    if awk -v d="$rear" -v f="$fan_depth" 'BEGIN { exit !(d <= f + 0.01) }'; then
        pass "$board: no duct (rear face at ${rear}mm, fan_depth ${fan_depth})"
    else
        fail "$board: rear face at ${rear}mm, past fan_depth ${fan_depth} — a duct leaked in"
    fi
done

# ---------------------------------------------------------------------------
# BLEED — the ring that feeds the under-board plenum must be open
# ---------------------------------------------------------------------------
if awk -v i="$INLET" -v b="$BORE" 'BEGIN { exit !(i < b) }'; then
    share=$(awk -v i="$INLET" -v b="$BORE" 'BEGIN { printf "%.0f", 100*i*i/(b*b) }')
    pass "bleed ring is open — duct takes ${share}% of the bore, ${INLET}mm inside ${BORE}mm"
else
    fail "duct_inlet_diameter ($INLET) is not inside the bore ($BORE): no bleed, plenum starved"
fi

# ---------------------------------------------------------------------------
# CLEARS — the duct must not run through the board on its way to the intake
# ---------------------------------------------------------------------------
"$OPENSCAD" --backend=Manifold --export-format=binstl -o "$WORK/clash.stl" \
    -D 'drawer_board="bitaxe_naja_duo"' -D 'setup_view="duct-clash"' cad/setup.scad \
    >"$WORK/clash.log" 2>&1
if grep -q ERROR "$WORK/clash.log"; then
    fail "duct/board clash check failed to render"
elif grep -q "top level object is empty" "$WORK/clash.log"; then
    pass "duct clears the board (empty intersection)"
else
    read -r ctris _ <<<"$(python3 "$STATS" "$WORK/clash.stl")"
    fail "duct intersects the board ($ctris triangles): $(python3 "$STATS" "$WORK/clash.stl" --bboxes | head -1)"
fi

# ---------------------------------------------------------------------------
# AIMED — the outlet must match the fan footprint it replaces
# ---------------------------------------------------------------------------
# 60.000 x 60.000 centred at Z 84.80, measured off the asset through the board
# transform. Asserted so that moving the board or its standoff without re-measuring
# cannot leave the duct pointing at the fins' edge.
if awk -v o="$OUTLET" 'BEGIN { exit !(o > 59.9 && o < 60.1) }' \
   && awk -v z="$OUT_Z" 'BEGIN { exit !(z > 84.7 && z < 84.9) }'; then
    pass "outlet matches the cooler fan footprint (${OUTLET}mm at Z ${OUT_Z})"
else
    fail "outlet is ${OUTLET}mm at Z ${OUT_Z}; the measured fan frame is 60.0 at Z 84.80"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ $CHECKS checks passed (duct ${LEN}mm long, ${INLET}mm inlet → ${OUTLET}mm outlet)"
    exit 0
fi
echo "❌ Cooler duct: $FAILURES of $CHECKS checks failed"
exit 1

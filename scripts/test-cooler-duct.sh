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
BLEED=$(cad duct_bleed_height)
OUTLET=$(cad duct_outlet_size)
OUT_Z=$(cad duct_outlet_z)
TRANS=$(cad duct_transition_length)
NOZZLE=$(cad duct_nozzle_length)

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
# BLEED — the opening that feeds the under-board plenum must be open
# ---------------------------------------------------------------------------
if awk -v h="$BLEED" -v b="$BORE" 'BEGIN { exit !(h > 0 && h < b/2) }'; then
    # Circular-segment area over the full bore: how much of the swept area spills.
    share=$(awk -v h="$BLEED" -v b="$BORE" 'BEGIN {
        r = b/2; d = r - h;
        seg = r*r*atan2(sqrt(r*r-d*d), d) - d*sqrt(r*r-d*d);
        printf "%.0f", 100*seg/(3.14159265*r*r) }')
    pass "bleed opening is ${BLEED}mm tall — roughly ${share}% of the bore spills to the plenum"
else
    fail "duct_bleed_height ($BLEED) is outside 0..$(awk -v b="$BORE" 'BEGIN{print b/2}') — plenum sealed or half the bore open"
fi

# ---------------------------------------------------------------------------
# OPEN — a duct capped at either end is a sealed, silent, useless tube
# ---------------------------------------------------------------------------
# By VOLUME, which is the one measurement that separates the two: a capped tube encloses
# its whole interior, an open one is wall material only. Triangle count, body count and
# genus all look healthy either way -- the first version of this duct was capped at both
# ends by a skin thinner than a layer and exported perfectly cleanly.
cat > "$WORK/duct-only.scad" <<'SCAD'
include <../cad/config.scad>
use <../cad/lib/shapes.scad>
use <../cad/sections/body/fan.scad>
fanDuct();
SCAD
"$OPENSCAD" --backend=Manifold --export-format=binstl -o "$WORK/duct-only.stl" \
    -D 'drawer_board="bitaxe_naja_duo"' "$WORK/duct-only.scad" >"$WORK/duct-only.log" 2>&1
if [ ! -s "$WORK/duct-only.stl" ]; then
    fail "could not render the duct on its own"
else
    dvol=$(python3 "$STATS" "$WORK/duct-only.stl" --volume)
    capped=$(awk -v s="$OUTLET" -v t="$TRANS" -v n="$NOZZLE" -v b="$BORE" 'BEGIN {
        r=b/2; printf "%.0f", ((3.14159265*r*r)+s*s)/2*(t+n) }')
    if awk -v v="$dvol" -v c="$capped" 'BEGIN { exit !(v < c*0.25) }'; then
        pass "duct is open at both ends (${dvol}mm3 of wall, vs ~${capped}mm3 if capped)"
    else
        fail "duct volume ${dvol}mm3 approaches the ~${capped}mm3 of a capped tube — an end is sealed"
    fi
fi

# ---------------------------------------------------------------------------
# REACHES — the nozzle has to end up INSIDE the pocket the fan vacated
# ---------------------------------------------------------------------------
# The first version stopped at 15, and the pocket does not start until 16.27: the duct
# ended in open case and the air had to find the fins by itself.
POCKET_LO=$(sed -n 's/^naja_duo_fan_pocket_y *= *\[ *\([0-9.]*\).*/\1/p' cad/lib/naja-duo-base.scad | head -1)
POCKET_HI=$(sed -n 's/^naja_duo_fan_pocket_y *= *\[[^,]*, *\([0-9.]*\).*/\1/p' cad/lib/naja-duo-base.scad | head -1)
END=$(awk -v t="$TRANS" -v n="$NOZZLE" 'BEGIN { print t+n }')
if awk -v e="$END" -v lo="$POCKET_LO" -v hi="$POCKET_HI" \
     'BEGIN { exit !(e > lo && e <= hi + 1.5) }'; then
    pass "nozzle ends at ${END}mm, inside the fan pocket (${POCKET_LO}..${POCKET_HI})"
else
    fail "nozzle ends at ${END}mm; the fan pocket is ${POCKET_LO}..${POCKET_HI} — it misses the cooler"
fi

# ---------------------------------------------------------------------------
# REACHES THE COOLER — the duct must actually meet the fins
# ---------------------------------------------------------------------------
# The complement of the clash check below, and the more important of the two. A duct that
# misses the cooler entirely passes every other check here: it is still one body, still
# open at both ends, still clear of the board. That is not hypothetical -- deepening the
# case for the rear pull fan slid the board 30mm backwards, because the section frame is
# flipped about back_depth, and left the duct pointing at empty air.
"$OPENSCAD" --backend=Manifold --export-format=binstl -o "$WORK/reach.stl" \
    -D 'drawer_board="bitaxe_naja_duo"' -D 'setup_view="duct-reach"' cad/setup.scad \
    >"$WORK/reach.log" 2>&1
if grep -q "top level object is empty" "$WORK/reach.log"; then
    fail "the duct does not touch the heatsink at all — it is aimed at empty case"
elif grep -q ERROR "$WORK/reach.log"; then
    fail "duct/heatsink reach check failed to render"
else
    rvol=$(python3 "$STATS" "$WORK/reach.stl" --volume)
    pass "duct meets the heatsink (${rvol}mm3 of overlap)"
fi

# The board's front edge is what the duct is aimed at, so it is pinned rather than left
# to fall where the case depth puts it.
FRONT=$("$OPENSCAD" -o "$WORK/se.echo" --export-format=echo \
    -D 'drawer_board="bitaxe_naja_duo"' cad/setup.scad >/dev/null 2>&1;
    grep -o 'HEXRACK_SETUP[^"]*' "$WORK/se.echo" | tr ' ' '\n' | sed -n 's/^boardFrontY=//p')
WANT=$(cad naja_board_front_y)
if awk -v a="$FRONT" -v b="$WANT" 'BEGIN { exit !(a - b < 0.01 && b - a < 0.01) }'; then
    pass "board front edge pinned at ${FRONT}mm, independent of back_depth"
else
    fail "board front edge is ${FRONT}mm but naja_board_front_y says ${WANT} — the case depth has dragged the board"
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

# ---------------------------------------------------------------------------
# REAR PULL FAN + USB-C PANEL — present on the Naja, absent on the others
# ---------------------------------------------------------------------------
# Probed rather than eyeballed, and probed BOTH WAYS. A hole that happens to coincide
# with an opening in the vent pattern passes a present-check on its own, so each feature
# is also checked against a board that should NOT have it: if the probe is open there
# too, the pattern made the hole and this code did nothing.
cat > "$WORK/probe.scad" <<'SCAD'
include <../cad/config.scad>
use <../cad/lib/shapes.scad>
use <../cad/sections/body/back-face.scad>
use <../cad/sections/body/back-fan.scad>
probe = "fanscrew";
bh = hex_flat_to_flat(body_width);
off = fan_mount_82_5 / 2;
// `part` selects which section to probe, so the same probe can be aimed at the part
// that SHOULD carry a feature and at the part that should no longer carry it.
part = "back-fan";
intersection() {
  if (part == "back-fan") sectionBackFan(); else sectionBackFace();

  if (probe == "fanscrew")
    for (sx = [-1, 1]) for (sz = [-1, 1])
      translate([body_width/2 + sx*off, -1, bh/2 + sz*off])
        rotate([-90,0,0]) cylinder(d = 2.0, h = back_fan_depth + 2, $fn = 24);
  else if (probe == "bore")
    translate([body_width/2, -1, bh/2]) rotate([-90,0,0])
      cylinder(d = rear_fan_bore - 4, h = back_fan_depth + 2, $fn = 64);
  else if (probe == "usbc")
    translate([body_width/2, -1, usbc_panel_z]) rotate([-90,0,0])
      cylinder(d = 4, h = back_face_thickness + 2, $fn = 24);
  else
    for (sx = [-1, 1])
      translate([body_width/2 + sx*usbc_panel_screw_pitch/2, -1, usbc_panel_z])
        rotate([-90,0,0]) cylinder(d = 1.4, h = back_face_thickness + 2, $fn = 24);
}
SCAD

open_at() {  # open_at <board> <probe> <part>  -> "open" | "blocked"
    "$OPENSCAD" --backend=Manifold --export-format=binstl -o "$WORK/probe.stl" \
        -D "drawer_board=\"$1\"" -D "probe=\"$2\"" -D "part=\"$3\"" "$WORK/probe.scad" \
        >"$WORK/probe.log" 2>&1
    grep -q "top level object is empty" "$WORK/probe.log" && echo open || echo blocked
}

# The fan bore and its screws: present in the back-fan SECTION, and gone from the back
# face, which used to carry them. The second half is the regression guard -- leaving both
# would put a 92mm hole in the outer panel that nothing fills.
for pair in "bore:92mm fan bore" "fanscrew:four 82.5mm fan screws"; do
    pr="${pair%%:*}"; what="${pair#*:}"
    infan=$(open_at "bitaxe_naja_duo" "$pr" "back-fan")
    inface=$(open_at "bitaxe_naja_duo" "$pr" "back-face")
    if [ "$infan" = "open" ] && [ "$inface" = "blocked" ]; then
        pass "$what is in the back-fan section, and no longer in the back face"
    elif [ "$infan" != "open" ]; then
        fail "$what is NOT cut in the back-fan section"
    else
        fail "$what is still cut in the back face too — the outer panel has an unfilled hole"
    fi
done

# The USB-C panel cutout stays in the back face. Probed against a board that has no rear
# fan, because a hole that merely coincides with an opening in the vent pattern would
# pass a present-check on its own.
for pair in "usbc:USB-C panel opening" "ear:USB-C screw ears"; do
    pr="${pair%%:*}"; what="${pair#*:}"
    naja=$(open_at "bitaxe_naja_duo" "$pr" "back-face")
    other=$(open_at "rock5b+" "$pr" "back-face")
    if [ "$naja" = "open" ] && [ "$other" = "blocked" ]; then
        pass "back face: $what cut on the Naja, absent on rock5b+"
    elif [ "$naja" != "open" ]; then
        fail "back face: $what is NOT cut on the Naja"
    else
        fail "back face: $what reads open on rock5b+ too — the vent pattern made that hole"
    fi
done

# The USB-C socket protrudes forward into the back-fan section, so it still has to sit
# below the fan bore -- the two are in different parts now but the same airway.
BORE_BOTTOM=$(awk -v b="$BORE" 'BEGIN { printf "%.2f", 150*0.8660254/2 - b/2 }')
USB_TOP=$(awk -v z="$(cad usbc_panel_z)" -v h="$(cad usbc_panel_height)" 'BEGIN { printf "%.2f", z + h/2 }')
if awk -v u="$USB_TOP" -v b="$BORE_BOTTOM" 'BEGIN { exit !(u < b) }'; then
    pass "USB-C opening tops out at ${USB_TOP}mm, clear of the bore at ${BORE_BOTTOM}mm"
else
    fail "USB-C opening reaches ${USB_TOP}mm but the fan bore starts at ${BORE_BOTTOM}mm — they overlap"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ $CHECKS checks passed (${TRANS}mm transition + ${NOZZLE}mm nozzle, ${BLEED}mm bleed)"
    exit 0
fi
echo "❌ Cooler duct: $FAILURES of $CHECKS checks failed"
exit 1

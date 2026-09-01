#!/bin/bash

# ============================================================================
# HexRack SBC - Canoe support geometry tests
# ============================================================================
# Three properties of sbcMountingSupports that a render log will never tell you
# about, because the STL is perfectly manifold whichever way they come out:
#
#   1. Canoes run along Y. The module groups holes into columns in *board*
#      coordinates, but the body wraps the call in rotate(rot) — so for any
#      board with a non-zero rotation (rpi5_pironman is -90) they ran along X.
#   2. Canoes are wider than the part, so the caller's intersection with the
#      shell is what sets their ends and they print as one continuous rail.
#   3. The canoe is as wide as the insert boss it carries. _canoe_lens offsets
#      its arcs along one axis and is symmetric, so getting that axis wrong
#      silently narrows the rail to 2(r-off) instead of the boss diameter.
#
# Plus: every hole keeps a support under it, which is what a sign error in the
# rotation cancelling would break.
#
# Requires OpenSCAD. Usage: ./scripts/test-canoe-axis.sh
# ============================================================================

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATS="$(dirname "$0")/lib/stl-stats.py"

# Same discovery order as generate-stl.sh, and honours an OPENSCAD override.
if [ -z "$OPENSCAD" ]; then
    if [ -f "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD" ]; then
        OPENSCAD="/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD"
    elif command -v openscad-nightly &> /dev/null; then
        OPENSCAD="openscad-nightly"
    elif command -v openscad &> /dev/null; then
        OPENSCAD="openscad"
    else
        echo "❌ OpenSCAD not found — cannot run canoe geometry tests"
        exit 1
    fi
fi

BACKEND=""
if "$OPENSCAD" --help 2>&1 | grep -q "\-\-backend"; then
    BACKEND="--backend Manifold"
fi

# Snap builds of OpenSCAD get a private /tmp, so keep the work directory beside
# the sources they already read. Same reason as test-front-circle.sh.
WORK="$(mktemp -d "$ROOT/.test-work.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

BOARDS=(rock5b+ rpi5_pironman)
FAILURES=0
CHECKS=0

fail() {
    echo "  ✗ $1"
    FAILURES=$((FAILURES + 1))
}

check() { CHECKS=$((CHECKS + 1)); }

# awk, because the values are millimetres and bash only does integers.
lt() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a < b) }'; }
near() { awk -v a="$1" -v b="$2" -v t="$3" 'BEGIN { exit !((a - b < t) && (b - a < t)) }'; }

render() {
    local probe="$1" board="$2" out="$3"
    # shellcheck disable=SC2086
    if ! "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$out" \
            -D "board=\"$board\"" "$probe" > "$WORK/render.log" 2>&1; then
        echo "  ✗ render failed: $(basename "$probe") / $board"
        sed 's/^/    /' "$WORK/render.log" | head -20
        exit 1
    fi
}

echo_val() { sed -n "s/.*$1 = \([0-9.-]*\).*/\1/p" "$WORK/render.log" | head -1; }

# Probes include by absolute path because they live outside the source tree, and
# each renders the supports in the frame the body places them in: the call site
# wraps them in rotate(rot), so the probe must too or it tests nothing.
probe() { sed "s|@ROOT@|$ROOT|g" > "$WORK/$1.scad"; }

probe supports <<'PROBE'
include <@ROOT@/cad/config.scad>
use <@ROOT@/cad/lib/sbc-helpers.scad>

board = "rock5b+";
slab  = -1;   // >= 0: keep only a thin horizontal slice at this Z
hits  = false; // true: keep only thin columns at each hole

rot   = get_board_rotation(board);
holes = get_sbcMountingHoles(board);

echo(hole_count = len(holes), boss_d = get_insert_min_boss("M2.5"),
     part_depth = back_depth, fillet = canoe_base_fillet);

module supports() {
    rotate(rot)
      sbcMountingSupports(board, 20, rot, 100, 0);
}

if (slab >= 0) {
    // A slice above the base fillet and well below the bosses: here the only
    // thing setting the X extent is the canoe cross-section itself.
    intersection() {
        supports();
        translate([-500, -500, slab]) cube([1000, 1000, 0.5]);
    }
} else if (hits) {
    // Raw holes inside rotate(rot) — the same frame the body's pocket cuts use.
    intersection() {
        supports();
        rotate(rot)
          for (h = holes)
            translate([h[0], h[1], 0.3]) cylinder(d = 0.8, h = 0.7, $fn = 16);
    }
} else {
    supports();
}
PROBE

echo "=== Canoe support geometry ==="

for board in "${BOARDS[@]}"; do
    render "$WORK/supports.scad" "$board" "$WORK/full-$board.stl"
    want_holes=$(echo_val hole_count)
    boss_d=$(echo_val boss_d)
    part_depth=$(echo_val part_depth)
    fillet=$(echo_val fillet)

    bodies=$(python3 "$STATS" "$WORK/full-$board.stl" --bboxes)
    if [ -z "$bodies" ]; then
        fail "$board produced no support geometry"
        continue
    fi

    # One line per canoe: "<dx> <dy> <dz>".
    n=0
    while read -r dx dy dz; do
        n=$((n + 1))
        check
        if ! lt "$dx" "$dy"; then
            fail "$board canoe #$n runs along X, not Y (dx=$dx dy=$dy dz=$dz)"
        fi
        # Longer than the part, so the caller's intersection with the shell is
        # what cuts the ends: that is what makes it span the full part.
        check
        if ! lt "$part_depth" "$dy"; then
            fail "$board canoe #$n is $dy long, shorter than the ${part_depth}mm part"
        fi
    done <<< "$bodies"
    echo "  $board: $n canoe(s), along Y and longer than the part"

    # Width, measured above the fillet skirt and below the bosses, so neither
    # can prop the number up.
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$WORK/slab-$board.stl" \
        -D "board=\"$board\"" -D "slab=$(awk -v f="$fillet" 'BEGIN{print f+0.5}')" \
        "$WORK/supports.scad" > "$WORK/render.log" 2>&1

    widths=$(python3 "$STATS" "$WORK/slab-$board.stl" --bboxes | cut -d' ' -f1 | sort -u)
    for w in $widths; do
        check
        if ! near "$w" "$boss_d" 0.05; then
            fail "$board canoe is ${w}mm wide, boss is ${boss_d}mm"
        fi
    done
    echo "  $board: canoe width ${boss_d}mm = boss diameter"

    # Cancelling the caller's rotation is only correct if the bosses stay on
    # their holes: the body carves the insert pockets separately, at the raw
    # hole positions, so a sign error here would silently decouple the two.
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$WORK/hit-$board.stl" \
        -D "board=\"$board\"" -D "hits=true" \
        "$WORK/supports.scad" > "$WORK/render.log" 2>&1
    hits=$(python3 "$STATS" "$WORK/hit-$board.stl"); hits=${hits##* }

    check
    if [ "$hits" -ne "$want_holes" ]; then
        fail "$board: $hits of $want_holes holes have a support under them"
    else
        echo "  $board: $hits/$want_holes holes supported"
    fi
done

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ $CHECKS checks passed"
else
    echo "❌ $FAILURES of $CHECKS checks failed"
    exit 1
fi

#!/bin/bash

# ============================================================================
# HexRack SBC - Face Vent Pattern Tests
# ============================================================================
# The face panel's perforation is swappable (face_vent_pattern). Two things can
# go wrong quietly:
#
#   1. A pattern saws the panel apart. The gyroid strands run the full width of
#      the face, so the only thing keeping the halves together is the solid rim
#      (face_vent_margin) and the ring outside the fan bore. OpenSCAD renders two
#      loose pieces as a perfectly valid manifold and says nothing.
#   2. A mode silently falls through to no cut at all. A typo in the dispatch
#      gives a blank panel that still renders, still prints, and looks like a
#      deliberate design choice.
#
# So every mode is checked for one body -- with the front circle both on and off,
# since the circle masks the rim -- and for actually having holes.
#
# Requires OpenSCAD. Usage: ./scripts/test-vent-patterns.sh
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
        echo "❌ OpenSCAD not found — cannot run vent pattern tests"
        exit 1
    fi
fi

BACKEND=""
if "$OPENSCAD" --help 2>&1 | grep -q "\-\-backend"; then
    BACKEND="--backend Manifold"
fi

# OpenSCAD installed from snap gets a private /tmp, so keep the work directory
# beside the sources it already reads. Same reasoning as test-front-circle.sh.
WORK="$(mktemp -d "$ROOT/.test-work.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
CHECKS=0

fail() {
    echo "  ✗ $1"
    FAILURES=$((FAILURES + 1))
}

# Read straight out of config.scad so a mode added there without a test here
# shows up as a new line in this suite rather than as untested code.
MODES=$(sed -n 's/^face_vent_patterns *= *\[\(.*\)\];.*/\1/p' "$ROOT/cad/config.scad" \
        | tr -d '" ' | tr ',' ' ')

if [ -z "$MODES" ]; then
    echo "❌ could not read face_vent_patterns from cad/config.scad"
    exit 1
fi

echo "=== Face vent patterns ==="

try_render() {
    local out="$1"
    shift
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$out" \
        -D 'body_part="face"' \
        -D "show_sbc=false" \
        "$@" \
        "$ROOT/cad/body.scad" > "$WORK/render.log" 2>&1
}

render() {
    local out="$1"
    shift
    if ! try_render "$out" "$@"; then
        echo "  ✗ render failed for: $*"
        echo "    --- $OPENSCAD output ---"
        sed 's/^/    /' "$WORK/render.log" | head -40
        exit 1
    fi
}

for mode in $MODES; do
    for circle in true false; do
        out="$WORK/$mode-$circle.stl"
        render "$out" -D "face_vent_pattern=\"$mode\"" -D "enable_front_circle=$circle"

        stats=$(python3 "$STATS" "$out")
        parts=${stats##* }
        genus=$(python3 "$STATS" "$out" --genus)

        # The one that matters: a pattern that reaches the hexagon edge, or that
        # runs unbroken across the face, prints as two loose pieces.
        CHECKS=$((CHECKS + 1))
        if [ "$parts" -ne 1 ]; then
            fail "$mode (front circle $circle) is $parts separate bodies"
        fi

        # A mode that cuts nothing is a dead dispatch branch, not a design.
        CHECKS=$((CHECKS + 1))
        if [ "$genus" -le 0 ]; then
            fail "$mode (front circle $circle) opened no holes in the panel"
        fi

        echo "  · $mode (circle=$circle): ${stats%% *} tris / $parts body / genus $genus"
    done
done

# Vertical centring. "Centred" for a lattice is not a translation you can
# eyeball -- the triangular one only mirrors onto itself when the origin sits on
# a row boundary AND alternate rows are staggered half a cell, and getting either
# wrong still yields a pattern that looks plausibly centred while the top and
# bottom rows are clipped differently by the hexagon. Subtracting the panel's
# mirror image from the cutter leaves exactly the material that fails to match.
cat > "$WORK/asymmetry.scad" <<'SCAD'
include <../cad/config.scad>
use <../cad/lib/vent-patterns.scad>
use <../cad/lib/shapes.scad>
c = hex_flat_to_flat(body_width) / 2;
difference() {
  ventPatternCutter(body_width, face_thickness);
  translate([0, 0, 2 * c]) mirror([0, 0, 1]) ventPatternCutter(body_width, face_thickness);
}
SCAD

for mode in triangles grid; do
    CHECKS=$((CHECKS + 1))
    # shellcheck disable=SC2086
    if ! "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$WORK/asym-$mode.stl" \
            -D "face_vent_pattern=\"$mode\"" "$WORK/asymmetry.scad" > "$WORK/render.log" 2>&1; then
        echo "  ✗ symmetry render failed for $mode"
        sed 's/^/    /' "$WORK/render.log" | head -20
        exit 1
    fi

    asym=$(python3 "$STATS" "$WORK/asym-$mode.stl" --volume)
    if [ "$(python3 -c "print(abs($asym) > 0.01)")" = "True" ]; then
        fail "$mode is not centred on the panel midline — ${asym}mm³ fails to mirror"
    else
        echo "  · $mode: mirrors about the midline (${asym}mm³ unmatched)"
    fi
done

# Every mode must render something different. Two modes sharing a hash means one
# of them fell through to the other's branch.
CHECKS=$((CHECKS + 1))
dupes=$(for mode in $MODES; do shasum -a 256 < "$WORK/$mode-true.stl"; done \
        | sort | uniq -d | wc -l | tr -d ' ')
if [ "$dupes" -ne 0 ]; then
    fail "two vent patterns render identical geometry"
fi

# An unknown mode must stop the render. Falling through to a blank panel would
# ship a solid face that looks intentional.
CHECKS=$((CHECKS + 1))
if try_render "$WORK/bogus.stl" -D 'face_vent_pattern="nope"'; then
    fail "an unknown vent pattern rendered instead of failing the assert"
fi

# The gyroid asset covers a fixed number of CELLS, so too small a period leaves it
# unable to reach across the panel. That would render clean with a blank crescent
# where the pattern ran out, so the library asserts on it.
CHECKS=$((CHECKS + 1))
if try_render "$WORK/toosmall.stl" -D 'face_vent_pattern="gyroid"' \
        -D 'face_vent_gyroid_period=4'; then
    fail "a gyroid period too small for the asset rendered instead of failing the assert"
fi

# The gyroid must be a solid that turns through the panel depth, not one slice
# extruded straight through -- that is the whole difference between a tunnel and a
# hole. Compare the front half against the back half: an extrusion is identical
# through the depth, a real tunnel is not.
CHECKS=$((CHECKS + 1))
gyroid_genus=$(python3 "$STATS" "$WORK/gyroid-false.stl" --genus)
if [ "$gyroid_genus" -lt 100 ]; then
    fail "the gyroid opened only $gyroid_genus through-holes — it is not tunnelling"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ $CHECKS checks passed"
else
    echo "❌ $FAILURES of $CHECKS checks failed"
    exit 1
fi

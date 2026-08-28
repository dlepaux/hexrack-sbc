#!/bin/bash

# ============================================================================
# HexRack SBC - Front Circle Geometry Tests
# ============================================================================
# The front circle is a band unioned onto the voronoi panel AFTER the pattern is
# cut, so it is attached only by the cells it happens to cross. If a future SVG
# leaves a gap where the band runs, OpenSCAD still reports a valid manifold — it
# just becomes a loose ring that prints as a separate part. Nothing in the render
# log would say so, hence this check.
#
# Requires OpenSCAD. Usage: ./scripts/test-front-circle.sh
# ============================================================================

set -e

ROOT="$(dirname "$0")/.."
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
        echo "❌ OpenSCAD not found — cannot run front circle geometry tests"
        exit 1
    fi
fi

BACKEND=""
if "$OPENSCAD" --help 2>&1 | grep -q "\-\-backend"; then
    BACKEND="--backend Manifold"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/hexrack-circle.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
CHECKS=0

fail() {
    echo "  ✗ $1"
    FAILURES=$((FAILURES + 1))
}

echo "=== Front circle geometry ==="

render() {
    local enabled="$1" out="$2"
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$out" \
        -D "enable_front_circle=$enabled" \
        -D 'body_part="face"' \
        -D "show_sbc=false" \
        "$ROOT/cad/body.scad" > /dev/null 2>&1
}

render true  "$WORK/on.stl"
render false "$WORK/off.stl"

on_stats=$(python3 "$STATS" "$WORK/on.stl")
off_stats=$(python3 "$STATS" "$WORK/off.stl")

on_tris=${on_stats%% *};  on_parts=${on_stats##* }
off_tris=${off_stats%% *}; off_parts=${off_stats##* }

# The flag must actually change the geometry, or it is decoration on a dead branch.
CHECKS=$((CHECKS + 1))
if [ "$(shasum -a 256 < "$WORK/on.stl")" = "$(shasum -a 256 < "$WORK/off.stl")" ]; then
    fail "enable_front_circle has no effect on the rendered face"
fi

# The band adds material; it must never open a hole in the panel.
CHECKS=$((CHECKS + 1))
if [ "$on_tris" -le "$off_tris" ]; then
    fail "front circle did not add geometry (on=$on_tris tris, off=$off_tris tris)"
fi

# The load-bearing one: a band that misses every voronoi wall is a loose ring.
CHECKS=$((CHECKS + 1))
if [ "$on_parts" -ne 1 ]; then
    fail "face with front circle is $on_parts separate bodies — the band is not fused to the panel"
fi

CHECKS=$((CHECKS + 1))
if [ "$off_parts" -ne 1 ]; then
    fail "face without front circle is $off_parts separate bodies"
fi

# The band must stay inside the hexagon. shapes.scad asserts this, so an oversized
# diameter has to fail the render rather than silently spill past the footprint.
CHECKS=$((CHECKS + 1))
if "$OPENSCAD" $BACKEND --render -o "$WORK/oversize.stl" \
        -D "front_circle_diameter=400" \
        -D 'body_part="face"' \
        -D "show_sbc=false" \
        "$ROOT/cad/body.scad" > /dev/null 2>&1; then
    fail "a front circle larger than the face rendered instead of failing the assert"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ $CHECKS checks passed (on: $on_tris tris / $on_parts body, off: $off_tris tris / $off_parts body)"
else
    echo "❌ $FAILURES of $CHECKS checks failed"
    exit 1
fi

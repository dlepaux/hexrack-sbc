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
        echo "❌ OpenSCAD not found — cannot run front circle geometry tests"
        exit 1
    fi
fi

BACKEND=""
if "$OPENSCAD" --help 2>&1 | grep -q "\-\-backend"; then
    BACKEND="--backend Manifold"
fi

# OpenSCAD installed from snap is strictly confined and gets a private /tmp, so a
# work directory under the host's /tmp is invisible to it: it refuses the output
# path with "is not a directory for output file" and renders nothing. Keep the
# work directory beside the sources it already reads.
WORK="$(mktemp -d "$ROOT/.test-work.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
CHECKS=0

fail() {
    echo "  ✗ $1"
    FAILURES=$((FAILURES + 1))
}

echo "=== Front circle geometry ==="

try_render() {
    local enabled="$1" out="$2"
    shift 2
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$out" \
        -D "enable_front_circle=$enabled" \
        -D 'body_part="face"' \
        -D "show_sbc=false" \
        "$@" \
        "$ROOT/cad/body.scad" > "$WORK/render.log" 2>&1
}

# Every render outside the assert check below is meant to succeed, and the checks
# read the resulting STL, so a failure here is fatal. It has to say why: with the
# output discarded, set -e would end the run on a bare exit code, printing nothing
# past the header. That is exactly how this suite failed silently on CI.
render() {
    local enabled="$1" out="$2"
    if ! try_render "$enabled" "$out"; then
        echo "  ✗ render failed for enable_front_circle=$enabled"
        echo "    --- $OPENSCAD output ---"
        sed 's/^/    /' "$WORK/render.log" | head -40
        echo "    --- environment ---"
        echo "    $("$OPENSCAD" --version 2>&1 | head -1)"
        echo "    voronoi asset: $(ls -l "$ROOT/cad/assets/voronoi_svg.svg" 2>&1 | tail -c 60)"
        echo "    submodule:     $(ls "$ROOT/cad/SBC_Model_Framework/" 2>&1 | tr '\n' ' ' | cut -c1-70)"
        exit 1
    fi
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

# The circle adds material; it must never open a hole in the panel.
#
# Measured by VOLUME, not by triangle count. Filling vent cells removes their walls, so a
# pattern with many small holes loses more triangles than the circle's own rim adds --
# this check read "on > off tris" and started failing the moment the default pattern
# changed from voronoi to triangles, reporting a regression that was not one.
CHECKS=$((CHECKS + 1))
on_vol=$(python3 "$STATS" "$WORK/on.stl" --volume)
off_vol=$(python3 "$STATS" "$WORK/off.stl" --volume)
if ! awk -v a="$on_vol" -v b="$off_vol" 'BEGIN { exit !(a > b) }'; then
    fail "front circle did not add material (on=${on_vol}mm3, off=${off_vol}mm3)"
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
if try_render true "$WORK/oversize.stl" -D "front_circle_diameter=400"; then
    fail "a front circle larger than the face rendered instead of failing the assert"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ $CHECKS checks passed (on: $on_tris tris / $on_parts body, off: $off_tris tris / $off_parts body)"
else
    echo "❌ $FAILURES of $CHECKS checks failed"
    exit 1
fi

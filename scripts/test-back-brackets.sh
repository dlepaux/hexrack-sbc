#!/bin/bash

# ============================================================================
# HexRack SBC - Back Bracket Alignment Test
# ============================================================================
# The back face screws onto two rear brackets, one in back-top and one in
# back-bottom. Each section places its own, and back-top's once ended 1mm past
# back_depth -- into the back face -- while back-bottom's stopped flush. Both
# render as clean single bodies; only comparing the two parts shows the offset.
#
# Both sections share the same front lip, so equal Y extents mean the rear
# brackets end on the same plane.
#
# Requires OpenSCAD. Usage: ./scripts/test-back-brackets.sh
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
        echo "❌ OpenSCAD not found — cannot run back bracket tests"
        exit 1
    fi
fi

BACKEND=""
if "$OPENSCAD" --help 2>&1 | grep -q "\-\-backend"; then
    BACKEND="--backend Manifold"
fi

# Beside the sources, not /tmp: a snap-confined OpenSCAD cannot see the host's /tmp.
WORK="$(mktemp -d "$ROOT/.test-work.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

echo "=== Back bracket alignment ==="

render() {
    local part="$1"
    # shellcheck disable=SC2086
    if ! "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$WORK/$part.stl" \
        -D "body_part=\"$part\"" -D "show_sbc=false" \
        "$ROOT/cad/body.scad" > "$WORK/$part.log" 2>&1; then
        echo "  ✗ render failed for $part"
        sed 's/^/    /' "$WORK/$part.log" | head -40
        exit 1
    fi
}

render back-top
render back-bottom

# --bboxes prints "dx dy dz" per body; each part is one body.
top_dy=$(python3 "$STATS" "$WORK/back-top.stl" --bboxes | awk '{ print $2 }')
bottom_dy=$(python3 "$STATS" "$WORK/back-bottom.stl" --bboxes | awk '{ print $2 }')

if awk -v a="$top_dy" -v b="$bottom_dy" 'BEGIN { d = a - b; exit !(d < 0.01 && d > -0.01) }'; then
    echo "✅ 1 check passed (both sections ${top_dy}mm deep)"
else
    echo "  ✗ back-top is ${top_dy}mm deep, back-bottom ${bottom_dy}mm — rear brackets not flush"
    echo "❌ 1 of 1 checks failed"
    exit 1
fi

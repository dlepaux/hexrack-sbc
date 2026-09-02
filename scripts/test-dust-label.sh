#!/bin/bash

# ============================================================================
# HexRack SBC - Dust Filter Label Tests
# ============================================================================
# The label is engraved into the dust filter's front face, in the 8.6mm band
# between its two hexagons. Two things can go wrong silently:
#
#   1. OpenSCAD falls back without complaint when a font is missing, so a runner
#      without the requested family renders *something* -- or, if text() yields
#      nothing at all, renders a blank part that still exports clean. Only
#      measuring the removed material catches that.
#   2. Text placed outside the band cuts into the ring's inner opening, which is
#      already empty. Nothing fails; the engraving is just partly missing. The
#      bounding-box check pins the label to material that exists.
#
# Requires OpenSCAD. Usage: ./scripts/test-dust-label.sh
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
        echo "❌ OpenSCAD not found — cannot run dust label tests"
        exit 1
    fi
fi

BACKEND=""
if "$OPENSCAD" --help 2>&1 | grep -q "\-\-backend"; then
    BACKEND="--backend Manifold"
fi

# Snap-confined OpenSCAD gets a private /tmp, so keep the work directory in-tree.
WORK="$(mktemp -d "$ROOT/.test-work.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
CHECKS=0
fail() { echo "  ✗ $1"; FAILURES=$((FAILURES + 1)); }

echo "=== Dust filter label ==="

try_render() {
    local out="$1"; shift
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$out" \
        -D 'body_part="dust"' \
        -D "show_sbc=false" \
        -D "show_antennas=false" \
        "$@" \
        "$ROOT/cad/body.scad" > "$WORK/render.log" 2>&1
}

render() {
    if ! try_render "$@"; then
        echo "  ✗ render failed:"
        sed 's/^/      /' "$WORK/render.log"
        exit 1
    fi
}

bbox() { python3 "$STATS" "$1" --bboxes | head -1; }
vol()  { python3 "$STATS" "$1" --volume; }

render "$WORK/plain.stl" -D 'dust_label_top=""' -D 'dust_label_bottom=""'
render "$WORK/labelled.stl" \
    -D 'dust_label_top="HEXRACK"' -D 'dust_label_bottom="NODE 01"'

# The label must actually do something. A silent font fallback that produces no
# glyphs would leave these two files identical.
CHECKS=$((CHECKS + 1))
if [ "$(shasum -a 256 < "$WORK/plain.stl")" = "$(shasum -a 256 < "$WORK/labelled.stl")" ]; then
    fail "dust_label_top/bottom did not change the rendered part — is text() producing glyphs?"
fi

# Engraving removes material. If the volume went UP the text is embossed, not
# engraved, and it will foul the face section it seats into.
CHECKS=$((CHECKS + 1))
plain_vol=$(vol "$WORK/plain.stl")
label_vol=$(vol "$WORK/labelled.stl")
if ! awk -v a="$label_vol" -v b="$plain_vol" 'BEGIN { exit !(a < b) }'; then
    fail "label did not remove material (plain=${plain_vol}mm3, labelled=${label_vol}mm3)"
fi

# The cut goes inward only. Any growth means the text escaped the front face and
# the part no longer fits its cavity.
CHECKS=$((CHECKS + 1))
if [ "$(bbox "$WORK/plain.stl")" != "$(bbox "$WORK/labelled.stl")" ]; then
    fail "label changed the part envelope: $(bbox "$WORK/plain.stl") -> $(bbox "$WORK/labelled.stl")"
fi

# The ring must stay one printable piece: a label deep or wide enough to sever the
# band would still export a valid manifold, just in two parts.
CHECKS=$((CHECKS + 1))
parts=$(python3 "$STATS" "$WORK/labelled.stl")
parts=${parts##* }
if [ "$parts" -ne 1 ]; then
    fail "labelled dust filter is $parts separate bodies — the engraving cut through the band"
fi

# Only one of the two labels set must still work; they are independent.
CHECKS=$((CHECKS + 1))
render "$WORK/top-only.stl" -D 'dust_label_top="TOP"'
if [ "$(shasum -a 256 < "$WORK/top-only.stl")" = "$(shasum -a 256 < "$WORK/plain.stl")" ]; then
    fail "dust_label_top alone had no effect"
fi

# The band is 8.6mm; a size past it has nowhere to go and must be refused rather
# than quietly spilling over both hexagon edges.
CHECKS=$((CHECKS + 1))
if try_render "$WORK/oversize.stl" -D 'dust_label_top="X"' -D "dust_label_size=12"; then
    fail "a label taller than the band rendered instead of failing the assert"
fi

# The PUBLISHED parts must carry no label whatever config.scad happens to hold: a label is
# per-unit, and whatever is set locally is somebody's hostname. generate-stl.sh forces
# them empty, and this asserts it keeps doing so.
CHECKS=$((CHECKS + 1))
if ! grep -q 'dust_label_top=' "$ROOT/scripts/generate-stl.sh" \
   || ! grep -q 'dust_label_bottom=' "$ROOT/scripts/generate-stl.sh"; then
    fail "generate-stl.sh no longer forces the labels empty — local labels would be published"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ $CHECKS checks passed (plain ${plain_vol}mm3 → labelled ${label_vol}mm3)"
else
    echo "❌ $FAILURES of $CHECKS checks failed"
    exit 1
fi

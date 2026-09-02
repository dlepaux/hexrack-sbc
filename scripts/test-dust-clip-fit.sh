#!/bin/bash

# ============================================================================
# HexRack SBC - Dust Filter Clip Fit
# ============================================================================
# The dust filter is held in the face section by two 45-degree ribs that bite into
# matching grooves in the face's inner wall. Rib and groove are ONE joint described in
# two files, and nothing about a render says whether they still meet:
#
#   Both parts export perfectly clean, and the assembly renders without complaint, no
#   matter how far apart the two halves drift. The joint simply stops existing -- the
#   filter is loose, or it will not seat at all because the rib lands on solid wall.
#
# That is not hypothetical. The groove was written as "face_depth - 2", which was correct
# only while face_depth happened to be dust_filter_depth + 2 + tolerance. The gyroid
# rework (51bff86) resized face_depth for the DEEPEST panel any pattern needs, 2mm -> 11mm,
# and dragged the groove 9mm off the rib on every pattern, gyroid included.
#
# So this measures the joint instead of trusting it: intersect the two parts and compare
# how deeply the rib sits inside the groove against the fit the joint had before the
# gyroid landed. And it checks that answer does not move with the vent pattern -- a
# cosmetic choice must never change a structural fit.
#
# Requires OpenSCAD. Usage: ./scripts/test-dust-clip-fit.sh
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
        echo "❌ OpenSCAD not found — cannot run dust clip fit tests"
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

# Measured at 51bff86^, the last commit where the joint demonstrably fitted, and unchanged
# by the repair. The rib is a 1.7mm square on the diagonal, so it stands 2.404mm proud;
# roughly half of that sits inside the groove, which is what makes it bite.
EXPECTED_VOLUME=22.221
BURIED_VOLUME=67.175   # what it measured while the groove was anchored to face_depth

echo "=== Dust filter clip fit ==="

cat > "$WORK/interference.scad" <<SCAD
include <$ROOT/cad/config.scad>
use <$ROOT/cad/sections/body/face.scad>
use <$ROOT/cad/sections/body/dust.scad>
intersection() { sectionFace(); sectionDust(); }
SCAD

# One number per pattern, so a pattern-coupled regression shows up as disagreement.
volumes=""
for pattern in triangles voronoi grid gyroid; do
    CHECKS=$((CHECKS + 1))
    out="$WORK/fit-$pattern.stl"
    # shellcheck disable=SC2086
    if ! "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$out" \
            -D "face_vent_pattern=\"$pattern\"" \
            -D "show_sbc=false" -D "show_antennas=false" \
            "$WORK/interference.scad" > /dev/null 2>&1; then
        fail "$pattern — the face/dust intersection failed to render"
        continue
    fi

    vol=$(python3 "$STATS" "$out" --volume)
    volumes="$volumes $vol"

    # A rib sitting on solid wall instead of in its groove reads as a much larger overlap.
    if awk -v v="$vol" -v e="$EXPECTED_VOLUME" 'BEGIN { exit !(v > e - 0.5 && v < e + 0.5) }'; then
        echo "  ✓ $pattern — rib engages the groove (${vol}mm3)"
    else
        awk -v v="$vol" -v b="$BURIED_VOLUME" 'BEGIN { exit !(v > b - 5) }' \
            && hint=" — that is the rib buried in the wall, not seated in the groove" \
            || hint=""
        fail "$pattern — clip overlap ${vol}mm3, expected ~${EXPECTED_VOLUME}mm3${hint}"
    fi
done

# The joint must not know which pattern is selected. This is the check that would have
# caught the original regression: face_depth grew for the gyroid, and the groove followed.
CHECKS=$((CHECKS + 1))
distinct=$(echo "$volumes" | tr ' ' '\n' | grep -v '^$' | sort -u | wc -l | tr -d ' ')
if [ "$distinct" != "1" ]; then
    fail "the clip fit varies with the vent pattern ($distinct distinct overlaps:$volumes)"
fi

# Belt and braces on the datum itself. Both halves must read the shared dust_clip_* values;
# re-deriving either from face_depth is exactly how they came apart last time.
CHECKS=$((CHECKS + 1))
if grep -q 'face_depth[^;]*sqrt(cube_length' "$ROOT/cad/sections/body/face.scad"; then
    fail "face.scad anchors the clip groove to face_depth again — it must use dust_clip_y"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ $CHECKS checks passed (clip overlap ${EXPECTED_VOLUME}mm3, identical on all 4 patterns)"
else
    echo "❌ $FAILURES of $CHECKS checks failed"
    exit 1
fi

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
#   3. The website engraves in the browser, from OpenSCAD-wasm over a PRUNED copy of
#      this cad/ tree. If dust geometry ever starts depending on the SBC submodule or
#      an asset, that render diverges from the published body-dust.stl -- at exit 0,
#      with warnings only. Rendering both trees and comparing bytes is the only check
#      that sees it.
#   4. The label is SPLICED INTO SOURCE by -D, so a quote in it is executable code.
#      An injected assert(false) prints ERROR and still exports a valid STL at exit 0,
#      so nothing downstream would notice.
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

# The width assert reads textmetrics(), which is an experimental builtin and returns undef
# -- silently passing the assert -- unless it is switched on. The whole point of this suite
# is to not trust a silent pass, so turn it on where the build supports it.
TEXTMETRICS=""
if "$OPENSCAD" --help 2>&1 | grep -q "enable"; then
    TEXTMETRICS="--enable=textmetrics"
fi

# Snap-confined OpenSCAD gets a private /tmp, so keep the work directory in-tree.
WORK="$(mktemp -d "$ROOT/.test-work.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
CHECKS=0
fail() { echo "  ✗ $1"; FAILURES=$((FAILURES + 1)); }

echo "=== Dust filter label ==="

# Parameterised over the cad/ root, because one check below renders the same part from a
# second, pruned tree and the two renders must differ in nothing but that root.
try_render_from() {
    local cad="$1" out="$2"; shift 2
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND $TEXTMETRICS --render --export-format=binstl -o "$out" \
        -D 'body_part="dust"' \
        -D "show_sbc=false" \
        -D "show_antennas=false" \
        "$@" \
        "$cad/body.scad" > "$WORK/render.log" 2>&1
}

try_render() { local out="$1"; shift; try_render_from "$ROOT/cad" "$out" "$@"; }

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

# A label wider than the band's flat is the one failure this suite could not see: the glyphs
# that run off remove LESS material, so the bounding box, the body count and the genus all
# stay exactly as they were, and the volume still goes down. Only an explicit width bound
# catches it. 18 digits span 68.9mm against 61.2mm of usable flat.
CHECKS=$((CHECKS + 1))
if [ -n "$TEXTMETRICS" ]; then
    if try_render "$WORK/overlong.stl" -D 'dust_label_top="123456789012345678"'; then
        fail "an 18-character label 68.9mm wide rendered instead of failing the width assert"
    fi
else
    echo "  · skipped width assert — this OpenSCAD has no --enable=textmetrics"
fi

# ...and the bound must not be so tight that ordinary labels stop fitting.
CHECKS=$((CHECKS + 1))
if ! try_render "$WORK/typical.stl" -D 'dust_label_top="HEXRACK"' -D 'dust_label_bottom="NODE 01"'; then
    fail "a typical two-line label no longer renders — the width bound is too tight"
fi

# --- The browser renders this part from a pruned tree --------------------------------
# The site engraves in-page with OpenSCAD-wasm, mounting only cad/**/*.{scad,cfg} minus the
# SBC_Model_Framework submodule (10MB of models the dust filter does not use), with two
# zero-byte stubs standing in for the files dust.scad include/uses, and no cad/assets/ at all.
#
# That prune is safe ONLY because the dust filter happens to touch neither. It is not safe in
# general: dropping the submodule silently changes back-bottom (154931 -> 124990 mm3) and
# dropping assets/ silently changes feet, both at exit 0 with warnings only. So if dust
# geometry ever starts reading sbc_data or importing an asset, the browser would quietly hand
# users a filter that differs from the published body-dust.stl -- same filename, same page,
# different part. Byte comparison is the only thing that catches it.
#
# Built from the mount RULE rather than a hand-written file list, so the test cannot drift
# from what the worker actually ships.
CHECKS=$((CHECKS + 1))
PRUNED="$WORK/pruned"
while IFS= read -r f; do
    mkdir -p "$PRUNED/cad/$(dirname "$f")"
    cp "$ROOT/cad/$f" "$PRUNED/cad/$f"
done < <(cd "$ROOT/cad" && find . -type f \( -name '*.scad' -o -name '*.cfg' \) \
             -not -path './SBC_Model_Framework/*' -not -path './assets/*' | sed 's|^\./||')
mkdir -p "$PRUNED/cad/SBC_Model_Framework"
: > "$PRUNED/cad/SBC_Model_Framework/sbc_models.scad"
: > "$PRUNED/cad/SBC_Model_Framework/sbc_models.cfg"

if ! try_render_from "$PRUNED/cad" "$WORK/pruned.stl" \
        -D 'dust_label_top="HEXRACK"' -D 'dust_label_bottom="NODE 01"'; then
    fail "the pruned tree the website mounts cannot render the dust filter at all:"
    sed 's/^/      /' "$WORK/render.log"
elif ! cmp -s "$WORK/labelled.stl" "$WORK/pruned.stl"; then
    fail "the dust filter differs between the full tree and the pruned tree the browser mounts \
— dust geometry now depends on the SBC submodule or cad/assets/, so the site would ship a \
filter that is not the published body-dust.stl"
fi

# --- The label is spliced into source, not passed as data ----------------------------
# -D dust_label_top="<text>" is TEXTUAL: OpenSCAD parses the assignment, so a label carrying
# a quote closes the string and everything after it is executable OpenSCAD. Verified, not
# assumed -- and the exit code is no help: an injected assert(false) prints
# "ERROR: Assertion 'false' failed" and OpenSCAD exports a valid STL at exit 0 anyway.
#
# The CAD cannot defend against this; only the caller can, by never letting " or \ through.
# These two checks keep both halves of that reasoning verifiable: the hazard is real, and
# the charset the website admits is inert.
CHECKS=$((CHECKS + 1))
try_render "$WORK/inject.stl" -D 'dust_label_top="X"; echo("HEXRACK_INJECTED"); z=""' || true
if ! grep -q HEXRACK_INJECTED "$WORK/render.log"; then
    fail "a quoted label no longer executes injected OpenSCAD. That is an improvement, but the \
website's /^[A-Za-z0-9 ._#+()-]{0,24}\$/ allowlist is documented as THE defence — confirm what \
changed before relaxing it on the strength of this"
fi

# Every non-alphanumeric character the allowlist admits, in one label: none may be a parse
# hazard, and none may fail the render. Alphanumerics and space are already covered above.
CHECKS=$((CHECKS + 1))
if ! try_render "$WORK/punct.stl" -D 'dust_label_top="A._#+()-9"'; then
    fail "the website's allowlisted punctuation no longer renders as text:"
    sed 's/^/      /' "$WORK/render.log"
elif grep -qi "^ERROR" "$WORK/render.log"; then
    fail "allowlisted punctuation produced an error rather than glyphs — the charset is no \
longer inert and the website's normalisation must shrink to match"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ $CHECKS checks passed (plain ${plain_vol}mm3 → labelled ${label_vol}mm3)"
else
    echo "❌ $FAILURES of $CHECKS checks failed"
    exit 1
fi

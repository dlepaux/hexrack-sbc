#!/bin/bash

# ============================================================================
# HexRack SBC - Dust Filter Support Tests
# ============================================================================
# The dust ring can carry wing-section ribs that hold the filter fabric flat
# (dust_support; plan/silent-front-design.md). The ribs are a stack of per-layer slabs
# unioned into the ring, and every way that goes wrong renders at exit 0:
#
#   1. Slab outlines that share a stretch of edge weld into a non-manifold mesh. It
#      exports, and the slicer "repairs" it into whatever it guesses.
#   2. Ribs clipped against the chamfer's sloped face leave microscopic voids and
#      tunnels. One body, clean export, wrong part. Only the genus sees them: the ring
#      has exactly as many through-holes as the ribs leave openings.
#   3. A rib that stops short of the glue-pocket floor leaves the fabric unsupported;
#      one that runs past it pokes through the fabric's plane.
#   4. A rib that reaches the band fills the engraving. The label still cuts, just less.
#   5. The browser engraves this part from a pruned tree. If the ribs ever depend on a
#      file the worker does not mount, the site ships a ring that is not the download.
#
# Requires OpenSCAD. Usage: ./scripts/test-dust-support.sh
# ============================================================================

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATS="$(dirname "$0")/lib/stl-stats.py"
# shellcheck source=lib/variant-matrix.sh
. "$(dirname "$0")/lib/variant-matrix.sh"
# shellcheck source=lib/pruned-tree.sh
. "$(dirname "$0")/lib/pruned-tree.sh"

# Same discovery order as generate-stl.sh, and honours an OPENSCAD override.
if [ -z "$OPENSCAD" ]; then
    if [ -f "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD" ]; then
        OPENSCAD="/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD"
    elif command -v openscad-nightly &> /dev/null; then
        OPENSCAD="openscad-nightly"
    elif command -v openscad &> /dev/null; then
        OPENSCAD="openscad"
    else
        echo "❌ OpenSCAD not found — cannot run dust support tests"
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

echo "=== Dust filter support ==="

# Labels are pinned empty unless a check sets them, so config.scad's local label cannot
# leak in. The support is always passed explicitly by the caller.
try_render_from() {
    local cad="$1" out="$2"; shift 2
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$out" \
        -D 'body_part="dust"' -D "show_sbc=false" -D "show_antennas=false" \
        -D 'dust_label_top=""' -D 'dust_label_bottom=""' \
        "$@" \
        "$cad/body.scad" > "$WORK/render.log" 2>&1
}
try_render() { local out="$1"; shift; try_render_from "$ROOT/cad" "$out" "$@"; }
render() {
    if ! try_render "$@"; then
        echo "  ✗ render failed: $*"
        sed 's/^/      /' "$WORK/render.log" | head -30
        exit 1
    fi
}

# OpenSCAD's own genus, from the mesh it built. stl-stats re-welds the exported STL at
# 1e-4mm, which merges the slabs' near-coincident vertices and over-counts.
openscad_genus() { sed -n 's/^ *Genus: *\([0-9-]*\).*/\1/p' "$WORK/render.log" | tail -1; }
vol() { python3 "$STATS" "$1" --volume; }
near() { LC_NUMERIC=C awk -v a="$1" -v b="$2" -v t="$3" 'BEGIN { exit !(a - b < t && b - a < t) }'; }

# The counts the genus depends on, read from the CAD so a retuned config moves the
# expectation with it rather than failing as a false alarm.
cat > "$WORK/counts.scad" <<SCAD
include <$ROOT/cad/config.scad>
echo(str("HEXRACK_DUST veins=", dust_vein_count, " cells=", len(dust_voronoi_seeds),
         " chord=", dust_filter_depth - 0.32, " eps=", EPS));
SCAD
"$OPENSCAD" -o "$WORK/counts.echo" --export-format=echo "$WORK/counts.scad" > /dev/null 2>&1
counts=$(grep -o 'HEXRACK_DUST[^"]*' "$WORK/counts.echo" | head -1)
count() { printf '%s' "$counts" | tr ' ' '\n' | sed -n "s/^$1=//p"; }
VEINS=$(count veins); CELLS=$(count cells); CHORD=$(count chord); EPS=$(count eps)
if [ -z "$VEINS" ] || [ -z "$CELLS" ] || [ -z "$CHORD" ] || [ -z "$EPS" ]; then
    echo "❌ could not read the dust support counts from cad/config.scad"
    exit 1
fi

expected_genus() {
    case "$1" in
        none)    echo 1 ;;          # the window
        veins)   echo "$VEINS" ;;   # one opening between each pair of veins
        voronoi) echo "$CELLS" ;;   # one opening per cell
        *)       echo "?" ;;
    esac
}

# --- 1. Every support is one clean body with exactly its openings ---------------------
for support in "${DUST_SUPPORTS[@]}"; do
    out="$WORK/$support.stl"
    render "$out" -D "dust_support=\"$support\""
    genus=$(openscad_genus)
    want=$(expected_genus "$support")
    stats=$(python3 "$STATS" "$out")
    parts=${stats##* }
    nm=$(python3 "$STATS" "$out" --nonmanifold)

    CHECKS=$((CHECKS + 1))
    [ "$parts" -eq 1 ] || fail "$support is $parts separate bodies"
    CHECKS=$((CHECKS + 1))
    [ "$nm" -eq 0 ] || fail "$support has $nm non-manifold edges — slab outlines share an edge"
    CHECKS=$((CHECKS + 1))
    [ "$genus" = "$want" ] \
        || fail "$support has genus $genus; its openings make $want — voids or tunnels where the ribs meet the ring"
    echo "  · $support: ${stats%% *} tris / $parts body / genus $genus / $nm non-manifold"
done

# Every rib mode must change the part. Two sharing a hash means one fell through.
CHECKS=$((CHECKS + 1))
dupes=$(for s in "${DUST_SUPPORTS[@]}"; do shasum -a 256 < "$WORK/$s.stl"; done \
        | sort | uniq -d | wc -l | tr -d ' ')
[ "$dupes" -eq 0 ] || fail "two dust supports render identical geometry"

# The vein count is a real parameter, not a constant that happens to be 3: the builder may
# need 4 or 5 to share no factor with the fan's blade count.
CHECKS=$((CHECKS + 1))
render "$WORK/veins-5.stl" -D 'dust_support="veins"' -D 'dust_vein_count=5'
[ "$(openscad_genus)" = "5" ] || fail "five veins leave genus $(openscad_genus), not 5 openings"

# The ribs hold up at every chamfer the ring allows, not only the default: the clip is
# derived from it, and the slab boundaries land differently against each.
for chamfer in 0 1 1.5; do
    for support in veins voronoi; do
        CHECKS=$((CHECKS + 1))
        render "$WORK/c.stl" -D "dust_support=\"$support\"" -D "dust_chamfer_max=$chamfer"
        g=$(openscad_genus); want=$(expected_genus "$support")
        nm=$(python3 "$STATS" "$WORK/c.stl" --nonmanifold)
        if [ "$g" != "$want" ] || [ "$nm" -ne 0 ]; then
            fail "$support at chamfer $chamfer: genus $g (want $want), $nm non-manifold edges"
        fi
    done
done

# --- 2. The ribs span exactly front face to glue floor ---------------------------------
# The ribs alone are the rib ring less the plain one. They must run from the ring's front
# face, which stands EPS proud of y = 0, to the glue-pocket floor at the chord: the fabric
# lies on their backs in the plane the pocket gives it at the edges. Measured as an extent,
# so the tolerance is far under EPS -- a rib a slab short or a slab long is 0.2mm out.
for support in veins voronoi; do
    CHECKS=$((CHECKS + 1))
    cat > "$WORK/ribs-$support.scad" <<SCAD
difference() { import("$WORK/$support.stl"); import("$WORK/none.stl"); }
SCAD
    # shellcheck disable=SC2086
    if ! "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$WORK/ribs-$support.stl" \
            "$WORK/ribs-$support.scad" > "$WORK/render.log" 2>&1; then
        fail "could not isolate the $support ribs"
        continue
    fi
    depth=$(python3 "$STATS" "$WORK/ribs-$support.stl" --bboxes \
            | awk 'NR == 1 || $2 > m { m = $2 } END { print m }')
    want=$(LC_NUMERIC=C awk -v c="$CHORD" -v e="$EPS" 'BEGIN { printf "%.3f", c + e }')
    near "$depth" "$want" 0.002 \
        || fail "$support ribs are ${depth}mm deep; front face to glue floor is ${want}mm"
    echo "  · $support ribs: ${depth}mm deep (front face to glue floor ${want}mm)"
done

# --- 3. The band is untouched: the label removes the same material on every ring -------
plain_cut=""
for support in "${DUST_SUPPORTS[@]}"; do
    CHECKS=$((CHECKS + 1))
    render "$WORK/$support-label.stl" -D "dust_support=\"$support\"" \
        -D 'dust_label_top="HEXRACK"' -D 'dust_label_bottom="NODE 01"'
    cut=$(LC_NUMERIC=C awk -v a="$(vol "$WORK/$support.stl")" -v b="$(vol "$WORK/$support-label.stl")" \
          'BEGIN { printf "%.3f", a - b }')
    [ -z "$plain_cut" ] && plain_cut="$cut"
    near "$cut" "$plain_cut" 0.05 \
        || fail "the label removes ${cut}mm3 from the $support ring but ${plain_cut}mm3 from the plain one — a rib reaches the band"
done

# --- 4. The browser's pruned tree renders the same ring ---------------------------------
PRUNED="$WORK/pruned"
build_pruned_tree "$ROOT" "$PRUNED"
for support in veins voronoi; do
    CHECKS=$((CHECKS + 1))
    if ! try_render_from "$PRUNED/cad" "$WORK/pruned-$support.stl" -D "dust_support=\"$support\"" \
            -D 'dust_label_top="HEXRACK"' -D 'dust_label_bottom="NODE 01"'; then
        fail "the pruned tree the website mounts cannot render the $support ring:"
        sed 's/^/      /' "$WORK/render.log" | head -20
    elif ! cmp -s "$WORK/$support-label.stl" "$WORK/pruned-$support.stl"; then
        fail "the $support ring differs between the full tree and the pruned tree the browser mounts"
    fi
done

# --- 5. The asserts refuse what cannot print or does not exist --------------------------
CHECKS=$((CHECKS + 1))
if try_render "$WORK/bogus.stl" -D 'dust_support="nope"'; then
    fail "an unknown dust_support rendered instead of failing the assert"
fi
CHECKS=$((CHECKS + 1))
if try_render "$WORK/thin.stl" -D 'dust_support="veins"' -D 'dust_rib_tail=0.6'; then
    fail "a 0.6mm trailing edge (under two 0.4mm lines) rendered instead of failing the assert"
fi
CHECKS=$((CHECKS + 1))
if try_render "$WORK/hub.stl" -D 'dust_support="veins"' -D 'dust_vein_hub=40'; then
    fail "a 40mm hub, past the fan's motor hub, rendered instead of failing the assert"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ $CHECKS checks passed"
else
    echo "❌ $FAILURES of $CHECKS checks failed"
    exit 1
fi

#!/bin/bash

# ============================================================================
# HexRack SBC - Feet fit tests
# ============================================================================
# A foot is the "case below" a staggered unit: it stands on the floor, and its
# "top" dovetail rail slides into the unit's bottom groove from the back. None of
# that shows up in a render log -- a rail that misses its groove, or a foot that
# stops short of the floor, exports exactly as cleanly as one that fits.
#
# For every feet_style, against each board's back parts (their supports differ):
#   1. one printable body (a clipped rail must not float free of the foot)
#   2. it reaches the floor, half a case below the unit, and not past it
#   3. seated and at every point of the slide out the back, it clears the case
#   4. not vacuous: without the "bottom" groove the same rail MUST collide
#   5. seated means home: 0.2mm further forward it hits the groove's stop, so the foot
#      in the model is where the slide actually leaves it
#   6. nothing overruns the case's depth -- the foot prints standing on an end, and a
#      rail tip past it is a first layer of rail alone
#   7. a triangle's rail runs flush to its back end, for a whole first layer there
#   8. the open triangle is a tube and the closed one is not
#
# Requires OpenSCAD. Usage: ./scripts/test-feet-fit.sh
# ============================================================================

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATS="$(dirname "$0")/lib/stl-stats.py"

if [ -z "$OPENSCAD" ]; then
    if [ -f "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD" ]; then
        OPENSCAD="/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD"
    elif command -v openscad-nightly &> /dev/null; then OPENSCAD="openscad-nightly"
    elif command -v openscad &> /dev/null; then OPENSCAD="openscad"
    else echo "❌ OpenSCAD not found — cannot run feet fit tests"; exit 1; fi
fi

BACKEND=""
if "$OPENSCAD" --help 2>&1 | grep -q "\-\-backend"; then BACKEND="--backend Manifold"; fi

# Snap builds get a private /tmp, so keep the work dir beside the sources.
WORK="$(mktemp -d "$ROOT/.test-work.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
fail() { echo "  ✗ $1"; FAILURES=$((FAILURES + 1)); }
near() { awk -v a="$1" -v b="$2" -v t="$3" 'BEGIN { exit !((a-b < t) && (b-a < t)) }'; }

sed "s|@ROOT@|$ROOT|g" > "$WORK/feet.scad" <<'PROBE'
include <@ROOT@/cad/config.scad>
use <@ROOT@/cad/lib/shapes.scad>
use <@ROOT@/cad/sections/body/feet.scad>
use <@ROOT@/cad/sections/body/face.scad>
use <@ROOT@/cad/sections/body/fan.scad>
use <@ROOT@/cad/sections/body/back-bottom.scad>
use <@ROOT@/cad/sections/body/back-face.scad>

what = "foot";
body_height = hex_flat_to_flat(body_width);
case_depth  = face_depth + fan_depth + back_depth + back_face_thickness;

// Every section a foot can touch, placed as cad/body.scad assembles them. back-top
// is the upper half and never comes near.
module caseBody() {
  sectionFace();
  translate([0, face_depth, 0]) sectionFan();
  translate([0, face_depth + fan_depth, 0]) sectionBackBottom();
  translate([0, face_depth + fan_depth + back_depth, 0]) sectionBackFace();
}

if (what == "foot") sectionFeet();

// A 1mm3 marker rides along because OpenSCAD refuses to export an empty object, and
// empty is what these probes hope for. Result = volume - 1.
module probe() { translate([-500, -500, -500]) cube(1); children(); }

// Material within a thin slab just above / just below the floor plane.
if (what == "floor")   probe() intersection() {
  sectionFeet();
  translate([-500, -500, -body_height/2]) cube([1000, 1000, 0.05]);
}
if (what == "subfloor") probe() intersection() {
  sectionFeet();
  translate([-500, -500, -body_height/2 - 1]) cube([1000, 1000, 1 - 0.01]);
}

// Anything outside the case's depth, Y 0..case_depth.
if (what == "overrun") probe() intersection() {
  sectionFeet();
  union() {
    translate([-500, -500, -500]) cube([1000, 500 - 0.001, 1000]);
    translate([-500, case_depth + 0.001, -500]) cube([1000, 500, 1000]);
  }
}

// Rail material in the last 0.05mm before the back end, above the bottom plane.
if (what == "tail") probe() intersection() {
  sectionFeet();
  translate([-500, case_depth - 0.05, 0.01]) cube([1000, 0.05, 10]);
}

// Pushed past its seat towards the front.
if (what == "home") probe() intersection() {
  caseBody();
  translate([0, -0.2, 0]) sectionFeet();
}

// Seated, then drawn out the back in steps until the rail has fully left the groove.
if (what == "slide") probe() intersection() {
  caseBody();
  for (s = [0, 5, 25, 60, 100, case_depth]) translate([0, s, 0]) sectionFeet();
}
PROBE

render() {  # render <what> <out> [extra -D...]
    local what="$1" out="$2"; shift 2
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$out" \
        -D "what=\"$what\"" "$@" "$WORK/feet.scad" > "$WORK/log" 2>&1 \
        || { echo "  ✗ render failed ($what $*)"; sed 's/^/    /' "$WORK/log" | head -10; exit 1; }
}
excess() { awk -v v="$(python3 "$STATS" "$1" --volume)" 'BEGIN { printf "%.4f", v - 1 }'; }

echo "=== Feet fit ==="

for board in rock5b+ rpi5_pironman; do
for style in trunk triangle triangle-closed; do
    echo "  [$board / $style]"
    S=(-D "feet_style=\"$style\"" -D "drawer_board=\"$board\"")

    # 1. One body.
    render foot "$WORK/foot.stl" "${S[@]}"
    bodies=$(python3 "$STATS" "$WORK/foot.stl" | cut -d' ' -f2)
    if [ "$bodies" != "1" ]; then
        fail "$style foot is $bodies bodies — part of it would print detached"
    else
        echo "    one body"
    fi

    # 2. On the floor, not through it.
    render floor "$WORK/floor.stl" "${S[@]}"
    render subfloor "$WORK/subfloor.stl" "${S[@]}"
    on=$(excess "$WORK/floor.stl"); under=$(excess "$WORK/subfloor.stl")
    if near "$on" 0 0.00001; then
        fail "$style foot stops short of the floor — the staggered unit hangs off its dovetails"
    elif ! near "$under" 0 0.001; then
        fail "$style foot reaches ${under} mm³ below the floor — the unit would sit proud of its neighbours"
    else
        echo "    stands on the floor, half a case down"
    fi

    # 3. Slides clear, seated and all the way out.
    render slide "$WORK/slide.stl" "${S[@]}"
    hit=$(excess "$WORK/slide.stl")
    if ! near "$hit" 0 0.001; then
        fail "$style foot interferes with the case by ${hit} mm³ somewhere along the slide"
    else
        echo "    slides clear of the case, seated to fully out"
    fi

    # 4. Not vacuous.
    render slide "$WORK/nogroove.stl" "${S[@]}" \
        -D 'dovetail_intercase=["top","top-right","top-left","bottom-left","bottom-right"]'
    hit=$(excess "$WORK/nogroove.stl")
    if near "$hit" 0 0.001; then
        fail "$style rail clears a case with NO bottom groove — it is not engaging the groove at all"
    else
        echo "    without the bottom groove the rail collides (${hit} mm³), so check 3 is real"
    fi

    # 5. Home against the stop.
    render home "$WORK/home.stl" "${S[@]}"
    hit=$(excess "$WORK/home.stl")
    if near "$hit" 0 0.001; then
        fail "$style foot can slide further forward than modelled — it does not seat on the groove stop"
    else
        echo "    seated against the groove stop (0.2mm further collides, ${hit} mm³)"
    fi

    # 6. Nothing past either end.
    render overrun "$WORK/overrun.stl" "${S[@]}"
    over=$(excess "$WORK/overrun.stl")
    if ! near "$over" 0 0.001; then
        fail "$style foot overruns the case depth by ${over} mm³ — it will not print flat on its end"
    else
        echo "    stays within the case depth"
    fi

    # 7. Flush rail on a triangle's printed end. The trunk's rail is clipped to its core.
    if [ "$style" != "trunk" ]; then
        render tail "$WORK/tail.stl" "${S[@]}"
        if near "$(excess "$WORK/tail.stl")" 0 0.00001; then
            fail "$style rail stops short of the back end — its first layer starts without it"
        else
            echo "    rail runs flush to the back end"
        fi
    fi

    # 8. Open means one through-hole, closed means none -- the two must not collapse into
    #    the same part under different names.
    case "$style" in
        triangle)        want=1 ;;
        triangle-closed) want=0 ;;
        *)               want="" ;;
    esac
    if [ -n "$want" ]; then
        genus=$(python3 "$STATS" "$WORK/foot.stl" --genus)
        if [ "$genus" != "$want" ]; then
            fail "$style has $genus through-hole(s), expected $want"
        else
            echo "    $genus through-hole(s), as a$([ "$want" = 1 ] && echo "n open" || echo " closed") triangle should"
        fi
    fi
done
done

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ Feet fit OK"
    exit 0
fi
echo "❌ Feet fit: $FAILURES failure(s)"
exit 1

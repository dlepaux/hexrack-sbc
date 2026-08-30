#!/bin/bash

# ============================================================================
# HexRack SBC - Fan Cable Notch Geometry Tests
# ============================================================================
# The four notches are cut into the fan web at the only four sites where the
# hexagon leaves identical material, and they are meant to open INTO the bore
# rather than close on themselves. A notch that fell short of the bore, or four
# notches where there should be one per corner, still render as a valid manifold
# and nothing in the log would say so.
#
# Genus is what separates those cases: merging with the existing bore leaves the
# through-hole count untouched, whereas four closed slots would add four. The
# volume band then pins how much material actually left, so a missing or wildly
# mis-sized notch cannot pass while the topology still looks right.
#
# Requires OpenSCAD. Usage: ./scripts/test-fan-wire-slots.sh
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
        echo "❌ OpenSCAD not found — cannot run fan cable notch geometry tests"
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

count() { CHECKS=$((CHECKS + 1)); }

# Float comparison without depending on bc.
lt() { python3 -c "import sys; sys.exit(0 if $1 < $2 else 1)"; }

echo "=== Fan cable notch geometry ==="

try_render() {
    local out="$1"
    shift
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$out" \
        -D 'body_part="fan"' \
        -D "show_fan=false" \
        -D "show_sbc=false" \
        "$@" \
        "$ROOT/cad/body.scad" > "$WORK/render.log" 2>&1
}

# Every render outside expect_rejected is meant to succeed, and the checks below
# read the resulting STL, so a failure here is fatal. Say why: under set -e an
# unreported non-zero would kill the run with no output at all.
render() {
    local out="$1"
    shift
    if ! try_render "$out" "$@"; then
        echo "  ✗ render failed for: $*"
        grep -m2 '^ERROR:' "$WORK/render.log" | sed 's/^/      /'
        exit 1
    fi
}

# A render that is expected to be rejected by one of the module's asserts.
expect_rejected() {
    local what="$1"
    shift
    count
    if try_render "$WORK/reject.stl" "$@"; then
        fail "$what rendered instead of failing the assert"
    fi
}

render "$WORK/on.stl"
render "$WORK/off.stl" -D "enable_fan_wire_slots=false"

on_parts=$(python3 "$STATS" "$WORK/on.stl");   on_parts=${on_parts##* }
off_parts=$(python3 "$STATS" "$WORK/off.stl"); off_parts=${off_parts##* }
on_genus=$(python3 "$STATS" "$WORK/on.stl" --genus)
off_genus=$(python3 "$STATS" "$WORK/off.stl" --genus)
on_vol=$(python3 "$STATS" "$WORK/on.stl" --volume)
off_vol=$(python3 "$STATS" "$WORK/off.stl" --volume)
removed=$(python3 -c "print(f'{$off_vol - $on_vol:.1f}')")

# The flag must actually change the geometry, or it is decoration on a dead branch.
count
if [ "$(shasum -a 256 < "$WORK/on.stl")" = "$(shasum -a 256 < "$WORK/off.stl")" ]; then
    fail "enable_fan_wire_slots has no effect on the rendered fan section"
fi

# Notches remove material; they must never add any.
count
if ! lt "$on_vol" "$off_vol"; then
    fail "notches did not remove material (on=$on_vol mm³, off=$off_vol mm³)"
fi

# The load-bearing one. Each notch has to merge into the bore, not close on
# itself: four closed slots would push the genus from 7 to 11.
count
if [ "$on_genus" -ne "$off_genus" ]; then
    fail "genus changed $off_genus → $on_genus — the notches did not open into the bore"
fi

count
if [ "$on_parts" -ne 1 ]; then
    fail "fan section with notches is $on_parts separate bodies"
fi
count
if [ "$off_parts" -ne 1 ]; then
    fail "fan section without notches is $off_parts separate bodies"
fi

# A sanity band, not a golden value: four notches at the stock parameters clear
# roughly 221mm³ each. A missing notch lands near 664, a doubled one near 1770,
# and either would otherwise sail past the topology checks above.
count
if ! lt 700 "$removed" || ! lt "$removed" 1100; then
    fail "removed $removed mm³, expected roughly 4 × 221 mm³ — a notch is missing or mis-sized"
fi

# The point of the whole feature: the fan's cable must find a clear path through
# the web. assets/noctua-92.stl puts the cable's exit at 239.85° from the panel
# centre, r = 53.2; it bends in a little to cross at roughly r = 50. Probe that
# spot for material. The negative control matters as much as the check itself —
# with the notches off the same probe must hit solid web, or it is aimed at air
# and would pass no matter what the notches did.
cat > "$WORK/cable-probe.scad" <<PROBE
include <$ROOT/cad/config.scad>
use <$ROOT/cad/sections/body/fan.scad>
use <$ROOT/cad/lib/shapes.scad>
cable_angle = 239.85;   // measured from assets/noctua-92.stl
cable_radius = 50;      // where the cable crosses the web, after bending in from 53.2
cable_diameter = 4;
intersection() {
  sectionFan();
  translate([body_width/2 + cable_radius * cos(cable_angle),
             fan_depth - 5,
             hex_flat_to_flat(body_width)/2 + cable_radius * sin(cable_angle)])
    rotate([-90, 0, 0])
      cylinder(d=cable_diameter, h=15, \$fn=32);
}
PROBE

probe() {
    local out="$1"
    shift
    rm -f "$out"
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$out" \
        -D "show_fan=false" -D "show_sbc=false" "$@" \
        "$WORK/cable-probe.scad" > /dev/null 2>&1 || true
    # An empty intersection writes no file at all. That is zero material blocking
    # the cable, i.e. the passing case, not an error.
    if [ -s "$out" ]; then
        python3 "$STATS" "$out" --volume
    else
        echo "0"
    fi
}

blocked_open=$(probe "$WORK/probe-open.stl")
blocked_shut=$(probe "$WORK/probe-shut.stl" -D "enable_fan_wire_slots=false")

count
if ! lt 1.0 "$blocked_shut"; then
    fail "cable probe found only $blocked_shut mm³ of web without notches — probe is misaimed"
fi
count
if ! lt "$blocked_open" 0.001; then
    fail "$blocked_open mm³ of web still blocks the cable path — the notches are not under the cable exit"
fi

# The radius knob has to reach the geometry, not just sit in config.scad.
render "$WORK/wide.stl" -D "fan_wire_slot_radius=9"
wide_vol=$(python3 "$STATS" "$WORK/wide.stl" --volume)
count
if ! lt "$wide_vol" "$on_vol"; then
    fail "raising fan_wire_slot_radius removed no extra material"
fi

# A different fan size shifts both the bore and the screw pattern, so the stock
# parameters have to still land the notch across the bore edge there too.
render "$WORK/f80-on.stl"  -D "fan_size_mode=80"
render "$WORK/f80-off.stl" -D "fan_size_mode=80" -D "enable_fan_wire_slots=false"
f80_on=$(python3 "$STATS" "$WORK/f80-on.stl" --genus)
f80_off=$(python3 "$STATS" "$WORK/f80-off.stl" --genus)
count
if [ "$f80_on" -ne "$f80_off" ]; then
    fail "80mm fan: genus changed $f80_off → $f80_on — the notch missed the bore"
fi

# Rotating the notch off the diagonal must move it without resizing it: the same
# stadium, swept about the bore centre, staying wholly inside the web at both ends.
render "$WORK/a0.stl" -D "fan_wire_slot_angle=0"
a0_vol=$(python3 "$STATS" "$WORK/a0.stl" --volume)
a0_removed=$(python3 -c "print(f'{$off_vol - $a0_vol:.1f}')")
count
if [ "$(shasum -a 256 < "$WORK/a0.stl")" = "$(shasum -a 256 < "$WORK/on.stl")" ]; then
    fail "fan_wire_slot_angle does not move the notches"
fi
count
if ! python3 -c "import sys; sys.exit(0 if abs($a0_removed - $removed) < 1.0 else 1)"; then
    fail "rotating changed how much material is removed ($a0_removed vs $removed mm³) — the notch left the web"
fi

# Every guard must abort the render rather than quietly shipping a weak part.
expect_rejected "a negative clearance beside the screw boss" -D "fan_wire_slot_clearance=-1"
expect_rejected "a fan size with no known screw pattern"      -D "fan_size_mode=120"
expect_rejected "a chamfer that consumes the whole web"       -D "fan_wire_slot_chamfer=2"
expect_rejected "a radius too small to cross the bore edge"   -D "fan_wire_slot_radius=3"
expect_rejected "a radius that merges adjacent notches"       -D "fan_wire_slot_radius=22"
expect_rejected "a reach that eats into the screw countersink" -D "fan_wire_slot_reach=8" -D "fan_wire_slot_angle=0"
# Reaching the tube wall takes a deliberately odd combination, because in any
# normal orientation the screw bosses stop the notch first. Swinging it to the
# mid-edge clears them and lets the hexagon bound be the one that fires.
expect_rejected "a notch swung out through the tube wall"     -D "fan_wire_slot_reach=20" -D "fan_wire_slot_radius=13" -D "fan_wire_slot_angle=45"

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ $CHECKS checks passed (genus $on_genus unchanged, $removed mm³ removed across 4 notches)"
else
    echo "❌ $FAILURES of $CHECKS checks failed"
    exit 1
fi

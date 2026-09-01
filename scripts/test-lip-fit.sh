#!/bin/bash

# ============================================================================
# HexRack SBC - Section lip fit tests
# ============================================================================
# The lip is an open rebate, not a closed groove: the female cutter reaches past
# the section's outer surface, so the tongue's OUTER face becomes the case's
# visible skin across the seam and the only locating surface is its INNER face.
# Two things follow, and neither shows up in a render log:
#
#   1. The outer face must stay exactly `body_width`. Any taper that touches it
#      opens a visible step at every seam.
#   2. The tongue must clear the rebate. The taper thins the tongue toward its
#      tip; get that sign backwards and it thickens instead, and the sections
#      simply will not seat -- but each part still renders and exports clean.
#
# Requires OpenSCAD. Usage: ./scripts/test-lip-fit.sh
# ============================================================================

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATS="$(dirname "$0")/lib/stl-stats.py"

if [ -z "$OPENSCAD" ]; then
    if [ -f "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD" ]; then
        OPENSCAD="/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD"
    elif command -v openscad-nightly &> /dev/null; then OPENSCAD="openscad-nightly"
    elif command -v openscad &> /dev/null; then OPENSCAD="openscad"
    else echo "❌ OpenSCAD not found — cannot run lip fit tests"; exit 1; fi
fi

BACKEND=""
if "$OPENSCAD" --help 2>&1 | grep -q "\-\-backend"; then BACKEND="--backend Manifold"; fi

# Snap builds get a private /tmp, so keep the work dir beside the sources.
WORK="$(mktemp -d "$ROOT/.test-work.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0; CHECKS=0
fail() { echo "  ✗ $1"; FAILURES=$((FAILURES + 1)); }
check() { CHECKS=$((CHECKS + 1)); }
gt() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'; }
near() { awk -v a="$1" -v b="$2" -v t="$3" 'BEGIN { exit !((a-b < t) && (b-a < t)) }'; }

sed "s|@ROOT@|$ROOT|g" > "$WORK/lip.scad" <<'PROBE'
include <@ROOT@/cad/config.scad>
use <@ROOT@/cad/lib/shapes.scad>
use <@ROOT@/cad/sections/body/back-top.scad>
use <@ROOT@/cad/sections/body/back-bottom.scad>

what  = "male";
depth = 40;      // stand-in section depth
slab  = -1;      // >= 0: keep only a thin slice this far from the tongue tip
push  = 0;       // extra insertion depth, to probe the rebate floor gap
below = 0.2;     // how far under the rebate floor to measure the outer width
at    = 0;       // Y of the back-top slice

echo(outer = body_width, clearance = lip_clearance, taper = lip_taper,
     floor_gap = lip_floor_gap, lip = lip_depth, ramp = lip_floor_ramp,
     reach = lipFemaleReach(), tongue = lipMaleLength(),
     seam = lipSeamGap(), margin = lipSeatMargin());

// The assembled joint: section N with its rebate, N+1's tongue seated in it. The
// outer width of a thin slice says whether the tongue is covering the cut there.
if (what == "seam")
    intersection() {
        union() {
            hostSection();
            translate([0, depth, 0]) honeycombLipMale();
        }
        translate([-500, at, -500]) cube([1000, 0.1, 1000]);
    }

// Whatever of back-bottom sits ABOVE the split plane. It is the lower half, so
// this must be empty -- but the half-section trim has to span the whole tongue to
// make it so, and the tongue is longer than lip_depth.
if (what == "halfleak") {
    translate([-50, -50, -50]) cube([1, 1, 1]);

    intersection() {
        sectionBackBottom();
        translate([-500, -lipMaleLength() - 1, hex_flat_to_flat(body_width) / 2 + 0.05])
            cube([1000, lipMaleLength() + 0.9, 1000]);
    }
}

// The male tongue as back-top actually emits it, after its own clip.
if (what == "toptongue") intersection() {
    sectionBackTop();
    translate([-500, -500, -500]) cube([1000, 500, 1000]);   // y < 0 only
}

// A thin slice of the real back-top, for checking what sits on its outer face at a
// given depth. Rendered with and without dovetail_intercase, the difference is
// exactly the intercase rail material present there.
if (what == "rail")
    intersection() {
        sectionBackTop();
        translate([-500, at, -500]) cube([1000, 0.2, 1000]);
    }

// Section N: a plain shell with the rebate cut into its far face.
module hostSection() {
    difference() {
        translate([0, 0, (-body_width + hex_flat_to_flat(body_width)) / 2])
        honeycomb_shell(body_width, depth, wall_thickness);

        honeycombLipFemale(depth);
    }
}

if (what == "female") honeycombLipFemale(depth);

if (what == "male") {
    if (slab < 0) honeycombLipMale();
    else
        intersection() {
            honeycombLipMale();
            // The tongue runs y = -lipMaleLength() .. 0 -- it reaches past the
            // rebate now -- so `slab` measures up from its real tip.
            translate([-500, -lipMaleLength() + slab, -500]) cube([1000, 0.2, 1000]);
        }
}

// A thin slice of the rebated section, `below` mm under the rebate floor. Its
// outer width is the whole measurement: a square floor leaves the full body_width
// right up to the corner, a ramp has not yet opened out to it.
if (what == "floor")
    intersection() {
        hostSection();
        translate([-500, depth - lip_depth - lip_floor_gap - below, -500])
            cube([1000, 0.1, 1000]);
    }

// Section N+1 seats against N's far face, so its tongue lands at y = depth.
// A 1mm3 marker rides along because OpenSCAD refuses to export an empty object,
// and empty is exactly the result we are hoping for. Interference = volume - 1.
if (what == "fit") {
    translate([-50, -50, -50]) cube([1, 1, 1]);

    intersection() {
        hostSection();
        translate([0, depth - push, 0]) honeycombLipMale();
    }
}
PROBE

render() {  # render <what> <out> [extra -D...]
    local what="$1" out="$2"; shift 2
    # shellcheck disable=SC2086
    "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$out" \
        -D "what=\"$what\"" "$@" "$WORK/lip.scad" > "$WORK/log" 2>&1 \
        || { echo "  ✗ render failed ($what $*)"; sed 's/^/    /' "$WORK/log" | head -10; exit 1; }
}

echo "=== Section lip fit ==="

render male "$WORK/male.stl"
outer=$(sed -n 's/.*outer = \([0-9.]*\).*/\1/p' "$WORK/log" | head -1)
clearance=$(sed -n 's/.*clearance = \([0-9.]*\).*/\1/p' "$WORK/log" | head -1)
floor_gap=$(sed -n 's/.*floor_gap = \([0-9.]*\).*/\1/p' "$WORK/log" | head -1)
lip=$(sed -n 's/.*lip = \([0-9.]*\).*/\1/p' "$WORK/log" | head -1)
ramp=$(sed -n 's/.*ramp = \([0-9.]*\).*/\1/p' "$WORK/log" | head -1)
tongue=$(sed -n 's/.*tongue = \([0-9.]*\).*/\1/p' "$WORK/log" | head -1)
seam=$(sed -n 's/.*seam = \([0-9.]*\).*/\1/p' "$WORK/log" | head -1)
wall=$(grep -E '^lip_wall' "$ROOT/cad/config.scad" | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')
margin=$(sed -n 's/.*margin = \([0-9.]*\).*/\1/p' "$WORK/log" | head -1)
reach=$(sed -n 's/.*reach = \([0-9.]*\).*/\1/p' "$WORK/log" | head -1)
back_depth=$(grep -E '^back_depth' "$ROOT/cad/config.scad" | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')


# 1. The outer face is the case's skin. It must not move.
dx=$(python3 "$STATS" "$WORK/male.stl" --bboxes | head -1 | cut -d' ' -f1)
check
if ! near "$dx" "$outer" 0.001; then
    fail "tongue outer width is ${dx}mm, must stay flush at ${outer}mm"
else
    echo "  outer face flush at ${outer}mm"
fi

# 2. The tongue must thin toward its tip, so it can follow the ramp down. Compare a
#    slice near the tip with one at the root: less material at the tip or it binds.
#    Measured on the wall itself, since lip_taper may legitimately be 0 -- the
#    45-degree skirt is what does the thinning now.
render male "$WORK/slab-tip.stl"  -D "slab=0.15"
render male "$WORK/slab-root.stl" -D "slab=$(awk -v t="$tongue" 'BEGIN{print t-0.35}')"
vt=$(python3 "$STATS" "$WORK/slab-tip.stl" --volume)
vr=$(python3 "$STATS" "$WORK/slab-root.stl" --volume)
check
if ! gt "$vr" "$vt"; then
    fail "tongue does not thin toward its tip (${vt} vs ${vr} mm³ per slice) — it will bind on the ramp"
else
    echo "  tongue thins toward the tip (${vt} vs ${vr} mm³ per 0.2mm slice)"
fi

# 3. The outer face must be full width for the tongue's WHOLE length, tip included.
#    It is the skin across the seam and it is what covers the rebate, so any break
#    in it exposes that much more of the cut.
render male "$WORK/tip.stl"  -D "slab=0.05"
render male "$WORK/root.stl" -D "slab=$(awk -v t="$tongue" 'BEGIN{print t-0.25}')"
tip_w=$(python3 "$STATS" "$WORK/tip.stl" --bboxes | head -1 | cut -d' ' -f1)
root_w=$(python3 "$STATS" "$WORK/root.stl" --bboxes | head -1 | cut -d' ' -f1)
check
if ! near "$tip_w" "$outer" 0.001; then
    fail "tongue is only ${tip_w}mm at the tip — a break there uncovers the rebate"
elif ! near "$root_w" "$outer" 0.001; then
    fail "tongue is only ${root_w}mm at the root — that is the visible seam face"
else
    echo "  outer face full ${outer}mm at both tip and root"
fi

# 4. The tongue must be its full length. The inner lead-in and the outer tip
#    45-degree tip eats into a wall only lip_wall - lip_taper thick; overrun it
#    and the cone breaks out through the outer face, shearing the tip off in a
#    feather edge. The part still renders -- just shorter, with degenerate
#    geometry where the cones cross.
dy=$(python3 "$STATS" "$WORK/male.stl" --bboxes | head -1 | cut -d' ' -f2)
check
if ! near "$dy" "$tongue" 0.05; then
    fail "tongue is ${dy}mm, not the ${tongue}mm it should reach — the tip is being eaten"
else
    echo "  tongue is its full ${tongue}mm (${dy}mm with eps), past the ${lip}mm rebate"
fi

# 5. And the module must refuse the case that causes it, rather than quietly
#    shipping a sheared tip.  (lip_tip_min = 1.5 against a 1.2mm tongue wall)
check
if "$OPENSCAD" $BACKEND --render --export-format=binstl -o "$WORK/bad.stl" \
        -D "what=\"male\"" -D "lip_tip_min=1.5" \
        "$WORK/lip.scad" > "$WORK/bad.log" 2>&1; then
    fail "an overlap past the available wall rendered instead of failing the assert"
else
    echo "  an overlap past the available wall is rejected by the assert"
fi

# 6. The cutter's outer wall must stand clear of the section's skin. Flush with
#    that skin -- or with a second overlapping cutter -- and the coincident faces
#    flicker in preview and make the CSG a coin toss. Out there it cuts only air,
#    so the clearance is free, but it has to actually be there.
render female "$WORK/cutter.stl"
cw=$(python3 "$STATS" "$WORK/cutter.stl" --bboxes | head -1 | cut -d' ' -f1)
check
if ! gt "$cw" "$(awk -v o="$outer" 'BEGIN{print o + 0.019}')"; then
    fail "female cutter is ${cw}mm against a ${outer}mm skin — not clear of coincidence"
else
    echo "  cutter stands $(awk -v c="$cw" -v o="$outer" 'BEGIN{printf "%.3f", c-o}')mm clear of the ${outer}mm skin"
fi

# 7. THE load-bearing one: the tongue must clear the rebate it seats into.
render fit "$WORK/fit.stl"
interference=$(awk -v v="$(python3 "$STATS" "$WORK/fit.stl" --volume)" 'BEGIN{printf "%.4f", v-1}')
check
if ! near "$interference" 0 0.001; then
    fail "tongue interferes with the rebate by ${interference} mm³ — the sections will not seat"
else
    echo "  tongue clears the rebate (0 mm³ interference)"
fi

# 8. Not vacuous: drive the clearance negative and the two MUST collide, or
#    check 3 is only proving that two empty solids do not overlap. It has to be
#    the clearance that is driven -- lip_female_wall is derived from lip_wall, so
#    thickening the tongue deepens the rebate to match and the fit stays nominal.
over=$(awk -v w="$clearance" 'BEGIN{print -w}')
render fit "$WORK/over.stl" -D "lip_clearance=$over" -D "lip_taper=0"
collide=$(awk -v v="$(python3 "$STATS" "$WORK/over.stl" --volume)" 'BEGIN{printf "%.4f", v-1}')
check
if ! gt "$collide" 0.001; then
    fail "a ${over}mm clearance did not collide — the fit check proves nothing"
else
    echo "  negative clearance collides as expected (${collide} mm³)"
fi

# 9. The rebate must be deeper than the tongue is long, or the sections seat on
#    the tongue tip instead of on their faces and the joint never closes. Probe it
#    by over-inserting: within the floor gap this must still not touch.
probe=$(awk -v m="$margin" 'BEGIN{printf "%.4f", m*0.6}')
render fit "$WORK/deep.stl" -D "push=$probe"
deep=$(awk -v v="$(python3 "$STATS" "$WORK/deep.stl" --volume)" 'BEGIN{printf "%.4f", v-1}')
check
if ! near "$deep" 0 0.001; then
    fail "over-inserting ${probe}mm already bottoms out (${deep} mm³) — under the ${margin}mm margin"
else
    echo "  ${margin}mm seating margin: ${probe}mm of over-insertion still clears"
fi

# 10. And not vacuous: pushed far enough it MUST bottom out. The threshold is well
#    past lip_floor_gap because the floor ramp relieves material below the floor
#    too -- measured, the tongue clears ~0.9mm of over-insertion, not 0.3mm. Probe
#    at floor_gap + ramp, which is past the end of the ramp and certainly solid.
past=$(awk -v m="$margin" -v r="$ramp" 'BEGIN{printf "%.4f", m + r + 0.2}')
render fit "$WORK/past.stl" -D "push=$past"
bottom=$(awk -v v="$(python3 "$STATS" "$WORK/past.stl" --volume)" 'BEGIN{printf "%.4f", v-1}')
check
if ! gt "$bottom" 0.001; then
    fail "over-inserting ${past}mm did not bottom out — the floor gap check proves nothing"
else
    echo "  ${past}mm of over-insertion bottoms out as expected (${bottom} mm³)"
fi

# 11. The rebate floor must ramp out to the outer surface, not step to it. Measure
#    the section's outer width just below the floor: a 45-degree ramp has only
#    recovered `below` mm of the cut there, so it must still be well under
#    body_width.
render floor "$WORK/floor.stl" -D "below=0.2"
fw=$(python3 "$STATS" "$WORK/floor.stl" --bboxes | head -1 | cut -d' ' -f1)
check
if ! gt "$outer" "$fw"; then
    fail "square rebate floor: still ${fw}mm wide 0.2mm under it"
else
    echo "  rebate floor ramps out (${fw}mm 0.2mm under it, vs ${outer}mm)"
fi

# 12. And it must reach full width again by the end of the ramp, or the ramp is
#    eating into the section rather than fading out.
render floor "$WORK/past.stl" -D "below=$(awk -v r="$ramp" 'BEGIN{print r+0.2}')"
pw=$(python3 "$STATS" "$WORK/past.stl" --bboxes | head -1 | cut -d' ' -f1)
check
if ! near "$pw" "$outer" 0.001; then
    fail "still ${pw}mm past the end of the ${ramp}mm ramp — it does not close"
else
    echo "  back to ${pw}mm past the ${ramp}mm ramp"
fi

# 13. Not vacuous: with the ramp off, that same slice must be full width.
render floor "$WORK/square.stl" -D "below=0.2" -D "lip_floor_ramp=0"
sw=$(python3 "$STATS" "$WORK/square.stl" --bboxes | head -1 | cut -d' ' -f1)
check
if ! near "$sw" "$outer" 0.001; then
    fail "ramp disabled but the floor is still ${sw}mm — the probe proves nothing"
else
    echo "  ramp disabled: square floor at ${sw}mm as expected"
fi

# 14. Nothing may sit on the outer face where the female cuts it away. back-top's
#     intercase dovetail rail is what does, and it used to end at a literal that
#     matched the rebate before the floor gap and ramp moved the cut 1.6mm back.
#     Measured on the real section: rails on minus rails off, inside the cut zone.
cut_at=$(awk -v b="$back_depth" -v r="$reach" 'BEGIN{printf "%.3f", b - r + 0.6}')
render rail "$WORK/rail-in.stl"  -D "at=$cut_at"
render rail "$WORK/norail-in.stl" -D "at=$cut_at" -D "dovetail_intercase=[]"
a=$(python3 "$STATS" "$WORK/rail-in.stl" --volume)
b=$(python3 "$STATS" "$WORK/norail-in.stl" --volume)
check
if ! near "$a" "$b" 0.001; then
    fail "intercase rail still adds $(awk -v x="$a" -v y="$b" 'BEGIN{printf "%.3f", x-y}') mm³ at y=${cut_at}, inside the cut"
else
    echo "  no rail material at y=${cut_at}, inside the female's reach"
fi

# 15. Not vacuous: before the cut zone the rail MUST be there, or check 14 is
#     only proving that back-top has no rails at all.
ok_at=$(awk -v b="$back_depth" -v r="$reach" 'BEGIN{printf "%.3f", b - r - 5}')
render rail "$WORK/rail-ok.stl"   -D "at=$ok_at"
render rail "$WORK/norail-ok.stl" -D "at=$ok_at" -D "dovetail_intercase=[]"
c=$(python3 "$STATS" "$WORK/rail-ok.stl" --volume)
d=$(python3 "$STATS" "$WORK/norail-ok.stl" --volume)
check
if ! gt "$(awk -v x="$c" -v y="$d" 'BEGIN{print x-y}')" 0.001; then
    fail "no rail material at y=${ok_at} either — the probe cannot see rails"
else
    echo "  rail present at y=${ok_at} ($(awk -v x="$c" -v y="$d" 'BEGIN{printf "%.1f", x-y}') mm³), as it must be"
fi

# 16. The point of the whole exercise: at the rebate floor the tongue must still
#     be covering the joint. It only does that by reaching past the floor and down
#     the ramp -- a tongue of exactly lip_depth stops short and leaves bare cut.
floor_at=$(awk -v d=40 -v l="$lip" -v g="$floor_gap" 'BEGIN{printf "%.3f", d - l - g}')
render seam "$WORK/seam-floor.stl" -D "at=$floor_at"
sf=$(python3 "$STATS" "$WORK/seam-floor.stl" --bboxes | head -1 | cut -d' ' -f1)
check
if ! near "$sf" "$outer" 0.001; then
    fail "at the rebate floor the seam is only ${sf}mm — the tongue is not covering it"
else
    echo "  tongue still covers the joint at the rebate floor (${sf}mm)"
fi

# 17. Not vacuous: a tongue of exactly lip_depth -- what it was before it reached
#     down the ramp -- must leave bare cut at that same spot.
# lip_tip_min = lip_wall - lip_taper drives lipMaleOverlap() to zero, so the tongue
# stops dead at the rebate floor -- which is where it stopped before this change.
short_at=$(awk -v d=40 -v l="$lip" -v g="$floor_gap" 'BEGIN{printf "%.3f", d - l - g - 0.05}')
render seam "$WORK/seam-short.stl" -D "at=$short_at" -D "lip_tip_min=$wall"
ss=$(python3 "$STATS" "$WORK/seam-short.stl" --bboxes | head -1 | cut -d' ' -f1)
check
if ! gt "$outer" "$ss"; then
    fail "a tongue stopping at the floor also reads ${ss}mm — the probe proves nothing"
else
    echo "  a tongue stopping at the floor leaves ${ss}mm there"
fi

# 18. The seam gap the geometry actually shows must be the one lipSeamGap() claims.
#     It is not a threshold to pass -- lip_floor_ramp is an explicit trade against
#     seating margin and ramp angle -- but the number has to be honest, because that
#     is what the config's trade-off table is read from. Probe just inside the band
#     and just inside the tongue that closes it.
mid=$(awk -v d=40 -v r="$reach" -v s="$seam" 'BEGIN{printf "%.4f", d - r + s/2}')
lip_edge=$(awk -v d=40 -v t="$tongue" 'BEGIN{printf "%.4f", d - t + 0.02}')
render seam "$WORK/seam-mid.stl"  -D "at=$mid"
render seam "$WORK/seam-edge.stl" -D "at=$lip_edge"
mw=$(python3 "$STATS" "$WORK/seam-mid.stl"  --bboxes | head -1 | cut -d' ' -f1)
ew=$(python3 "$STATS" "$WORK/seam-edge.stl" --bboxes | head -1 | cut -d' ' -f1)
check
if ! gt "$outer" "$mw"; then
    fail "mid-band at y=${mid} reads ${mw}mm — no gap there, so lipSeamGap() overstates it"
elif ! near "$ew" "$outer" 0.001; then
    fail "the tongue does not close the band at y=${lip_edge} (${ew}mm) — gap is wider than ${seam}mm"
else
    echo "  seam gap measures ${seam}mm as claimed (${mw}mm mid-band, ${ew}mm past it)"
fi

# 19. And the band it cannot cover is only what is left of the ramp beyond it.
gap_w=$(awk -v r="$reach" -v t="$tongue" 'BEGIN{printf "%.2f", r - t}')
past=$(awk -v d=40 -v t="$tongue" 'BEGIN{printf "%.3f", d - t - 0.1}')
render seam "$WORK/seam-past.stl" -D "at=$past"
sp=$(python3 "$STATS" "$WORK/seam-past.stl" --bboxes | head -1 | cut -d' ' -f1)
check
if ! gt "$outer" "$sp"; then
    fail "past the tongue tip the seam still measures ${sp}mm — the probe sees nothing"
else
    echo "  ${gap_w}mm of ramp left exposed past the tip (${sp}mm there), down from ${ramp}mm"
fi

# 20. back-bottom is the lower half. Its half-section trim has to span the whole
#     tongue, not lip_depth -- otherwise the tip keeps its upper half and fouls
#     back-top's tongue on assembly. Renders clean either way.
render halfleak "$WORK/leak.stl"
leak=$(awk -v v="$(python3 "$STATS" "$WORK/leak.stl" --volume)" 'BEGIN{printf "%.3f", v-1}')
check
if ! near "$leak" 0 0.01; then
    fail "back-bottom leaks ${leak} mm³ above the split plane — the trim misses the tongue tip"
else
    echo "  back-bottom keeps nothing above the split plane"
fi

# 21. And back-top's own clip must reach the tongue's real tip rather than sawing
#     the end off, which is how a longer tongue silently stays short.
render toptongue "$WORK/toptongue.stl"
tdy=$(python3 "$STATS" "$WORK/toptongue.stl" --bboxes | head -1 | cut -d' ' -f2)
check
if ! near "$tdy" "$tongue" 0.05; then
    fail "back-top's tongue is only ${tdy}mm of ${tongue}mm — its clip cube cuts it short"
else
    echo "  back-top emits the full ${tongue}mm tongue (${tdy}mm)"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then echo "✅ $CHECKS checks passed"
else echo "❌ $FAILURES of $CHECKS checks failed"; exit 1; fi

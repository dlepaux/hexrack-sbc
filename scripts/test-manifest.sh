#!/bin/bash

# ============================================================================
# MANIFEST v2 CONTRACT TEST
# ============================================================================
# The manifest is the ONLY interface between the CI build and the configurator.
# The configurator generates its controls from `.axes` and resolves parts by
# comparing `.parts[].options` — it never parses a filename. So the contract is:
#
#   every combination the axes can express resolves to EXACTLY ONE part
#
# Zero matches is a broken download button. Two matches is worse: the resolver
# picks one arbitrarily and the user prints a part that is not what they chose.
# This walks the whole cross-product and fails on either.
#
# Usage:
#   ./scripts/test-manifest.sh [path/to/manifest.json]
# Defaults to public/manifest.json, falling back to the committed dev fixture.
# ============================================================================

set -uo pipefail

MANIFEST="${1:-}"
if [ -z "$MANIFEST" ]; then
    if   [ -f public/manifest.json ];               then MANIFEST=public/manifest.json
    elif [ -f website/fixtures/manifest.json ];     then MANIFEST=website/fixtures/manifest.json
    else echo "❌ no manifest found (pass one as \$1)"; exit 1
    fi
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq is required"; exit 1
fi
if [ ! -s "$MANIFEST" ]; then
    echo "❌ manifest missing or empty: $MANIFEST"; exit 1
fi

echo "=== Manifest contract: $MANIFEST ==="

FAILURES=0
fail() { echo "  ✗ $1"; FAILURES=$((FAILURES + 1)); }
pass() { echo "  ✓ $1"; }

# ---------------------------------------------------------------------------
# 1. Shape
# ---------------------------------------------------------------------------
for path in schemaVersion generated commit axes layout hardware parts groups; do
    jq -e "has(\"$path\")" "$MANIFEST" > /dev/null \
        || fail "missing top-level key: $path"
done

ver=$(jq -r '.schemaVersion // 0' "$MANIFEST")
[ "$ver" = "2" ] || fail "schemaVersion is $ver, expected 2"

# Every part needs the fields the resolver reads. A part without `part` or `options`
# is invisible to the configurator no matter how well-formed the rest of it is.
bad=$(jq -r '[.parts[] | select((has("part")|not) or (has("options")|not)
                                or (has("file")|not) or (has("bytes")|not)
                                or (has("triangles")|not))] | length' "$MANIFEST")
[ "$bad" = "0" ] || fail "$bad part(s) missing part/options/file/bytes/triangles"

# Triangle counts are what the preview budgets against; a zero means stl_triangles()
# silently failed and the site would under-budget a mesh it cannot afford to load.
zero=$(jq -r '[.parts[] | select(.triangles == 0 or .bytes == 0)] | length' "$MANIFEST")
[ "$zero" = "0" ] || fail "$zero part(s) report 0 bytes or 0 triangles"

dupes=$(jq -r '[.parts[].file] | group_by(.) | map(select(length > 1)) | length' "$MANIFEST")
[ "$dupes" = "0" ] || fail "$dupes filename(s) recorded more than once"

[ "$FAILURES" -eq 0 ] && pass "shape"

# ---------------------------------------------------------------------------
# 2. Completeness over the axis cross-product
# ---------------------------------------------------------------------------
# Resolution rules, expressed once here and mirrored by the website resolver:
#   face         <- ventPattern x frontCircle
#   back-top     <- male dovetail subset
#   back-bottom  <- board x female subset
#   back-face    <- board x antennas x backFaceVent(ventPattern) x female subset
#   dust/fan/feet have no options
#
# Dovetail subsets are compared as SETS, so the order the build wrote them in cannot
# make a lookup miss.
RESULT=$(jq -r '
  def subsets($xs):
    if ($xs | length) == 0 then [[]]
    else ( subsets($xs[1:]) ) as $rest
         | $rest + ($rest | map([$xs[0]] + .))
    end;
  def sameset($a; $b): ($a | sort) == ($b | sort);

  . as $m
  | $m.axes as $ax
  | ($ax.ventPattern.values)            as $vents
  | ($ax.ventPattern.backFaceFallback // {}) as $fallback
  | ($ax.board.values)                  as $boards
  | ($ax.frontCircle.values)            as $circles
  | ($ax.antennas.values)               as $antennas
  | subsets($ax.faces.male)             as $maleSets
  | subsets($ax.faces.female)           as $femaleSets

  | [
      # --- unconditional parts -------------------------------------------
      ( ["dust","fan","feet"][] as $p
        | { want: $p,
            n: ([ $m.parts[] | select(.part == $p) ] | length) } ),

      # --- face -----------------------------------------------------------
      ( $vents[] as $v | $circles[] as $c
        | { want: "face \($v) circle=\($c)",
            n: ([ $m.parts[]
                  | select(.part == "face"
                           and .options.ventPattern == $v
                           and .options.frontCircle == $c) ] | length) } ),

      # --- back-top --------------------------------------------------------
      ( $maleSets[] as $s
        | { want: "back-top \($s)",
            n: ([ $m.parts[]
                  | select(.part == "back-top" and sameset(.options.dovetails; $s)) ]
                | length) } ),

      # --- back-bottom -----------------------------------------------------
      ( $boards[] as $b | $femaleSets[] as $s
        | { want: "back-bottom \($b) \($s)",
            n: ([ $m.parts[]
                  | select(.part == "back-bottom"
                           and .options.board == $b
                           and sameset(.options.dovetails; $s)) ] | length) } ),

      # --- back-face -------------------------------------------------------
      # The chosen face pattern maps through backFaceFallback first, exactly as the
      # website must. That is what makes a fallback entry testable rather than folklore.
      ( $boards[] as $b | $antennas[] as $a | $vents[] as $v | $femaleSets[] as $s
        | ($fallback[$v] // $v) as $bv
        | { want: "back-face \($b) ant=\($a) vent=\($v)->\($bv) \($s)",
            n: ([ $m.parts[]
                  | select(.part == "back-face"
                           and .options.board == $b
                           and .options.antennas == $a
                           and .options.ventPattern == $bv
                           and sameset(.options.dovetails; $s)) ] | length) } )
    ]
  | map(select(.n != 1))
  | if length == 0 then "OK"
    else (map("\(if .n == 0 then "MISSING" else "AMBIGUOUS(\(.n))" end)  \(.want)")
          | .[0:25] | join("\n")) + "\n__COUNT__\(length)"
    end
' "$MANIFEST")

if [ "$RESULT" = "OK" ]; then
    total=$(jq -r '[.parts[]] | length' "$MANIFEST")
    pass "every axis combination resolves to exactly one part ($total parts)"
else
    n=$(printf '%s' "$RESULT" | sed -n 's/^__COUNT__//p')
    printf '%s\n' "$RESULT" | grep -v '^__COUNT__' | sed 's/^/      /'
    fail "${n:-?} axis combination(s) do not resolve to exactly one part"
fi

# ---------------------------------------------------------------------------
# 3. Cross-checks against the CAD
# ---------------------------------------------------------------------------
# The default vent pattern must be the one cad/config.scad actually defaults to, or the
# un-suffixed body-face.stl stops meaning what showcase.scad and old links expect.
if [ -f cad/config.scad ]; then
    cad_default=$(sed -n 's/^face_vent_pattern *= *"\([a-z]*\)".*/\1/p' cad/config.scad | head -1)
    man_default=$(jq -r '.axes.ventPattern.default' "$MANIFEST")
    if [ -n "$cad_default" ] && [ "$cad_default" != "$man_default" ]; then
        fail "axes.ventPattern.default is '$man_default' but cad/config.scad defaults to '$cad_default'"
    else
        pass "default vent pattern agrees with cad/config.scad ('$man_default')"
    fi
fi

# The layout offsets drive the client-side assembled preview; a wrong one is a preview
# with a floating panel, which reads as a CAD bug rather than a manifest bug.
#
# Compared against what the CAD says NOW, never against literals here. face_depth is
# derived from the gyroid's cell size, so every one of these moves when that changes --
# a copy written into this test would be exactly the drift the test exists to catch.
if [ -n "${OPENSCAD:-}" ] || command -v openscad-nightly &> /dev/null \
   || command -v openscad &> /dev/null \
   || [ -f "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD" ]; then
    OS="${OPENSCAD:-}"
    [ -z "$OS" ] && [ -f "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD" ] \
        && OS="/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD"
    [ -z "$OS" ] && command -v openscad-nightly &> /dev/null && OS="openscad-nightly"
    [ -z "$OS" ] && OS="openscad"

    lay_tmp="$(mktemp "${TMPDIR:-/tmp}/hexrack-layout.XXXXXX")"
    "$OS" -o "$lay_tmp" --export-format=echo cad/layout-export.scad > /dev/null 2>&1
    echo_line=$(grep -o 'HEXRACK_LAYOUT[^"]*' "$lay_tmp" | head -1)
    rm -f "$lay_tmp"
    if [ -z "$echo_line" ]; then
        fail "cad/layout-export.scad emitted no layout"
    else
        cad_val() { printf '%s' "$echo_line" | tr ' ' '\n' | sed -n "s/^$1=//p"; }
        lay_bad=0
        for pair in "dust:dust" "face:face" "fan:fan" \
                    "back-bottom:backBottom" "back-top:backTop" "back-face:backFace"; do
            key="${pair%%:*}"; src="${pair##*:}"
            got=$(jq -r --arg k "$key" '.layout.partOffsetY[$k]' "$MANIFEST")
            want=$(cad_val "$src")
            if ! awk -v a="$got" -v b="$want" 'BEGIN { exit !(a - b < 0.001 && b - a < 0.001) }'; then
                fail "layout.partOffsetY.$key is $got but the CAD says $want"
                lay_bad=1
            fi
        done
        [ "$lay_bad" -eq 0 ] && pass "assembly layout offsets agree with the CAD"
    fi
else
    echo "  · skipped layout cross-check (no OpenSCAD)"
fi

# Feet drop must equal half the hexagon's flat-to-flat, because that is the offset a
# staggered column has to bridge.
feet_ok=$(jq -r '((.layout.hex.flatToFlat / 2) - .layout.feet.drop | fabs) < 0.01' "$MANIFEST")
[ "$feet_ok" = "true" ] && pass "feet drop equals half a case height" \
                        || fail "layout.feet.drop is not flatToFlat/2"

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ Manifest contract OK"
    exit 0
fi
echo "❌ Manifest contract: $FAILURES failure(s)"
exit 1

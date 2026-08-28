#!/bin/bash

# ============================================================================
# HexRack SBC - Variant Matrix Tests
# ============================================================================
# The dovetail bitmask expansion decides both the OpenSCAD override and the STL
# filename for 56 of the 66 generated parts, so a silent off-by-one here would
# ship a wall of mislabelled downloads. These assertions run without OpenSCAD.
#
# Usage: ./scripts/test-variant-matrix.sh
# ============================================================================

set -e

# shellcheck source=lib/variant-matrix.sh
. "$(dirname "$0")/lib/variant-matrix.sh"

FAILURES=0
CHECKS=0

assert_eq() {
    local expected="$1" actual="$2" what="$3"
    CHECKS=$((CHECKS + 1))
    if [ "$expected" != "$actual" ]; then
        echo "  ✗ $what"
        echo "      expected: $expected"
        echo "      actual:   $actual"
        FAILURES=$((FAILURES + 1))
    fi
}

echo "=== Variant matrix ==="

# --- Bitmask -> OpenSCAD list literal ---------------------------------------
# Bit i selects the i-th face of the triple, so the mask reads little-endian.
assert_eq 'dovetail_intercase=["top","top-right","top-left"]' \
          "$(dovetail_defn 7 "${MALE_FACES[@]}")" "mask 7 selects the whole male triple"
assert_eq 'dovetail_intercase=[]' \
          "$(dovetail_defn 0 "${MALE_FACES[@]}")" "mask 0 selects nothing"
assert_eq 'dovetail_intercase=["top"]' \
          "$(dovetail_defn 1 "${MALE_FACES[@]}")" "mask 1 selects bit 0 only"
assert_eq 'dovetail_intercase=["top-right"]' \
          "$(dovetail_defn 2 "${MALE_FACES[@]}")" "mask 2 selects bit 1 only"
assert_eq 'dovetail_intercase=["top-left"]' \
          "$(dovetail_defn 4 "${MALE_FACES[@]}")" "mask 4 selects bit 2 only"
assert_eq 'dovetail_intercase=["top","top-left"]' \
          "$(dovetail_defn 5 "${MALE_FACES[@]}")" "mask 5 skips the middle face"
assert_eq 'dovetail_intercase=["bottom","bottom-left"]' \
          "$(dovetail_defn 3 "${FEMALE_FACES[@]}")" "the female triple expands independently"

# --- Bitmask -> filename code -----------------------------------------------
assert_eq "all"   "$(dovetail_code 7 "${MALE_FACES[@]}")"   "mask 7 is the default, named 'all'"
assert_eq "none"  "$(dovetail_code 0 "${MALE_FACES[@]}")"   "mask 0 is named 'none'"
assert_eq "t"     "$(dovetail_code 1 "${MALE_FACES[@]}")"   "single male face abbreviates"
assert_eq "t-tl"  "$(dovetail_code 5 "${MALE_FACES[@]}")"   "abbreviations join with a dash"
assert_eq "b-bl"  "$(dovetail_code 3 "${FEMALE_FACES[@]}")" "female faces abbreviate distinctly"
assert_eq "bl-br" "$(dovetail_code 6 "${FEMALE_FACES[@]}")" "female diagonals abbreviate distinctly"

# --- Bitmask -> display label -----------------------------------------------
assert_eq "All faces"       "$(dovetail_label 7 "${MALE_FACES[@]}")" "default label"
assert_eq "No dovetails"    "$(dovetail_label 0 "${MALE_FACES[@]}")" "empty label"
assert_eq "top + top-left"  "$(dovetail_label 5 "${MALE_FACES[@]}")" "labels join with a plus"

# --- Codes must be unique, or variants silently overwrite each other ---------
for triple in male female; do
    if [ "$triple" = male ]; then faces=("${MALE_FACES[@]}"); else faces=("${FEMALE_FACES[@]}"); fi

    codes=""
    count=0
    for mask in $DOVETAIL_MASKS; do
        codes="$codes$(dovetail_code "$mask" "${faces[@]}")
"
        count=$((count + 1))
    done

    assert_eq 8 "$count" "$triple triple enumerates 2^3 subsets"
    assert_eq 8 "$(printf '%s' "$codes" | sort -u | wc -l | tr -d ' ')" \
              "$triple triple yields 8 distinct filename codes"
done

# The two triples share a filename namespace only across different parts, but a
# collision would still make the download page ambiguous.
all_codes=""
for mask in $DOVETAIL_MASKS; do
    all_codes="$all_codes$(dovetail_code "$mask" "${MALE_FACES[@]}")
$(dovetail_code "$mask" "${FEMALE_FACES[@]}")
"
done
assert_eq 14 "$(printf '%s' "$all_codes" | sort -u | wc -l | tr -d ' ')" \
          "male and female codes overlap only on 'all' and 'none'"

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "✅ $CHECKS checks passed"
else
    echo "❌ $FAILURES of $CHECKS checks failed"
    exit 1
fi

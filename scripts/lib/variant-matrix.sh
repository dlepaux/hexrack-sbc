#!/bin/bash

# ============================================================================
# VARIANT MATRIX
# ============================================================================
# Two independent axes over disjoint parts, so they never multiply each other:
#
#   front circle        -> body-face only (on/off)
#   intercase dovetails -> back-top (males), back-bottom + back-face (females)
#
# back-top only ever reads the three faces the case presents upward, and the two
# female parts only ever read the three it presents downward. Neither looks at the
# other's triple, so "every combination" is the 8 subsets of ONE triple per part
# (2^3) — not the 64 subsets of all six faces.

# Bit i of a mask selects face i of a triple, and the triples are ordered so that bit i
# names a MATING PAIR under the hex tiling: top<->bottom, top-right<->bottom-left,
# top-left<->bottom-right. dovetailIntercase() leans on that pairing, so the two arrays
# must keep the same length and the same order.
#
# Consumed by whichever script sources this file, so shellcheck cannot see the use.
# shellcheck disable=SC2034
MALE_FACES=(top top-right top-left)
# shellcheck disable=SC2034
FEMALE_FACES=(bottom bottom-left bottom-right)

if [ "${#MALE_FACES[@]}" -ne "${#FEMALE_FACES[@]}" ]; then
    echo "❌ variant-matrix: the face triples must pair up one-to-one" >&2
    exit 1
fi

# Derived rather than written out, so widening a triple enumerates the new subsets
# instead of silently generating half of them under the old "all" label.
ALL_MASK=$(( (1 << ${#MALE_FACES[@]}) - 1 ))

# Default first, so it leads each listing.
# shellcheck disable=SC2034
DOVETAIL_MASKS="$ALL_MASK $(seq 0 $((ALL_MASK - 1)) | tr '\n' ' ')"

# Abbreviation used to keep variant filenames short.
face_abbrev() {
    case "$1" in
        top)          echo "t"  ;;
        top-right)    echo "tr" ;;
        top-left)     echo "tl" ;;
        bottom)       echo "b"  ;;
        bottom-left)  echo "bl" ;;
        bottom-right) echo "br" ;;
    esac
}

# Expand a 0..7 bitmask over a face triple into an OpenSCAD list literal.
dovetail_defn() {
    local mask=$1; shift
    local out="" i=0 name
    for name in "$@"; do
        if [ $(( (mask >> i) & 1 )) -eq 1 ]; then
            out="$out${out:+,}\"$name\""
        fi
        i=$((i + 1))
    done
    echo "dovetail_intercase=[$out]"
}

# Filename code for a mask: "all", "none", or dash-joined abbreviations ("t-tr").
dovetail_code() {
    local mask=$1; shift
    local out="" i=0 name
    if [ "$mask" -eq "$ALL_MASK" ]; then echo "all";  return 0; fi
    if [ "$mask" -eq 0 ];          then echo "none"; return 0; fi
    for name in "$@"; do
        if [ $(( (mask >> i) & 1 )) -eq 1 ]; then
            out="$out${out:+-}$(face_abbrev "$name")"
        fi
        i=$((i + 1))
    done
    echo "$out"
}

# Human-readable label for the download page.
dovetail_label() {
    local mask=$1; shift
    local out="" i=0 name
    if [ "$mask" -eq "$ALL_MASK" ]; then echo "All faces";    return 0; fi
    if [ "$mask" -eq 0 ];          then echo "No dovetails"; return 0; fi
    for name in "$@"; do
        if [ $(( (mask >> i) & 1 )) -eq 1 ]; then
            out="$out${out:+ + }$name"
        fi
        i=$((i + 1))
    done
    echo "$out"
}

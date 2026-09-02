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

# ============================================================================
# FACE VENT PATTERNS
# ============================================================================
# A third axis, over the two panels that call ventPatternCutter(): the face
# (cad/sections/body/face.scad:53) and the back face (back-face.scad:68).
#
# "gyroid" is here now that it cuts real tunnels: the panel is one full period deep and
# the pattern comes from a meshed isosurface (assets/gyroid-tunnels.stl) instead of the
# old stacked closed-form slices, which could never sweep more than a quarter turn and
# cost 1,520,620 facets / 76MB / 79s. It is now ~52,700 facets / 2.6MB / 2s.
#
# It stays off the BACK face -- back_face_vent() below -- because that panel is 3mm, and
# a gyroid needs a whole period of depth or its web falls into separate pieces.
# shellcheck disable=SC2034
FACE_VENT_PATTERNS=(triangles voronoi grid gyroid)

# The pattern that keeps the un-suffixed filename, so body-face.stl and
# body-back-face-<board>.stl keep meaning what they meant before this axis existed
# (cad/showcase.scad imports assemblies built from them, and old links stay alive).
# Derived from the list rather than written twice, and asserted against cad/config.scad
# by scripts/test-variant-matrix.sh so the two cannot drift.
# shellcheck disable=SC2034
DEFAULT_VENT_PATTERN="${FACE_VENT_PATTERNS[0]}"

# The pattern the back face carries for a given face pattern. Identity today; the
# hook exists so gyroid can fall back to triangles the moment it joins the list
# above, instead of that rule being rediscovered at render time.
back_face_vent() {
    case "$1" in
        gyroid) echo "triangles" ;;
        *)      echo "$1" ;;
    esac
}

# The DISTINCT patterns the back face actually needs, once the fallback has collapsed
# some of them onto each other. Looping the back face over FACE_VENT_PATTERNS instead
# emits the identical file once per face pattern that maps to it, which is not merely
# wasteful: the manifest then holds two parts matching one configuration and the
# resolver picks whichever it sees first.
back_face_patterns() {
    local p bf out=""
    for p in "${FACE_VENT_PATTERNS[@]}"; do
        bf=$(back_face_vent "$p")
        case " $out " in
            *" $bf "*) ;;
            *) out="$out $bf" ;;
        esac
    done
    printf '%s' "${out# }"
}

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

# JSON array of the selected face names, for the manifest's machine-readable options.
# The website resolves a part by comparing this against the set its grid derives, so it must
# stay the face NAMES -- never the abbreviations, which exist only to keep filenames short.
dovetail_faces_json() {
    local mask=$1; shift
    local out="" i=0 name
    for name in "$@"; do
        if [ $(( (mask >> i) & 1 )) -eq 1 ]; then
            out="$out${out:+,}\"$name\""
        fi
        i=$((i + 1))
    done
    echo "[$out]"
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

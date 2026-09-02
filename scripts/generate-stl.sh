#!/bin/bash

# ============================================================================
# HexRack SBC - STL Generation Script
# ============================================================================
# Simple sequential STL generation. Auto-detects macOS vs Linux.
#
# Usage:
#   ./scripts/generate-stl.sh              # Auto-detect environment
#   ./scripts/generate-stl.sh --local      # Force local preset
#   ./scripts/generate-stl.sh --ci         # Force CI preset
# ============================================================================

set -e  # Exit on error (but we handle OpenSCAD errors gracefully)

# Track failures for summary
MANIFEST_ERRORS=0
FAILED_PARTS=""
TOTAL_PARTS=0
SUCCESS_PARTS=0

# ============================================================================
# ENVIRONMENT DETECTION
# ============================================================================

# macOS OpenSCAD paths (prefer nightly for Manifold support)
MACOS_OPENSCAD_NIGHTLY="/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD"
MACOS_OPENSCAD_STABLE="/Applications/OpenSCAD-2021.01.app/Contents/MacOS/OpenSCAD"
FORCE_MODE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --local) FORCE_MODE="local"; shift ;;
        --ci) FORCE_MODE="ci"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Detect environment
if [ "$FORCE_MODE" = "local" ]; then
    ENV_MODE="local"
elif [ "$FORCE_MODE" = "ci" ]; then
    ENV_MODE="ci"
elif [ -f "$MACOS_OPENSCAD_NIGHTLY" ]; then
    ENV_MODE="local"
elif [ -f "$MACOS_OPENSCAD_STABLE" ]; then
    ENV_MODE="local"
elif command -v openscad-nightly &> /dev/null; then
    ENV_MODE="ci"
elif command -v openscad &> /dev/null; then
    ENV_MODE="ci"
else
    echo "❌ Error: OpenSCAD not found"
    echo ""
    echo "Install OpenSCAD:"
    echo "  macOS: Download from https://openscad.org/downloads.html (Development Snapshots)"
    echo "  Linux: snap install openscad-nightly"
    exit 1
fi

# ============================================================================
# CONFIGURATION
# ============================================================================

COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MANIFEST_FILE="public/manifest.json"

if [ "$ENV_MODE" = "local" ]; then
    echo "🍎 Using LOCAL preset (macOS)"
    # Prefer nightly for Manifold backend support
    if [ -f "$MACOS_OPENSCAD_NIGHTLY" ]; then
        OPENSCAD="$MACOS_OPENSCAD_NIGHTLY"
    else
        OPENSCAD="$MACOS_OPENSCAD_STABLE"
    fi
    DATE=$(date +%Y-%m-%d-%H%M)
    OUTPUT_DIR="output/${DATE}-${COMMIT_HASH}"
    GENERATE_MANIFEST=false
else
    echo "🤖 Using CI preset (Linux)"
    # Prefer openscad-nightly (snap) for Manifold backend support
    if command -v openscad-nightly &> /dev/null; then
        OPENSCAD="openscad-nightly"
    else
        OPENSCAD="${OPENSCAD:-openscad}"
    fi
    OUTPUT_DIR="public/stl"
    GENERATE_MANIFEST=true
fi

# Verify OpenSCAD
if [ ! -f "$OPENSCAD" ] && ! command -v "$OPENSCAD" &> /dev/null; then
    echo "❌ Error: OpenSCAD not found at $OPENSCAD"
    exit 1
fi

# Get OpenSCAD version
OPENSCAD_VERSION=$("$OPENSCAD" --version 2>&1 | head -1)
echo "📦 OpenSCAD: $OPENSCAD_VERSION"

# Check for Manifold backend support (available in nightly/2024+)
# Manifold is 10-100x faster and doesn't have CGAL cache issues
OPENSCAD_EXTRA_ARGS=""
if "$OPENSCAD" --help 2>&1 | grep -q "\-\-backend"; then
    echo "✅ Manifold backend available - using for faster rendering"
    OPENSCAD_EXTRA_ARGS="--backend Manifold"
else
    echo "ℹ️  Manifold backend not available (older OpenSCAD version)"
fi

# ============================================================================
# MAIN SCRIPT
# ============================================================================

START_TIME=$(date +%s)


mkdir -p "$OUTPUT_DIR"

echo ""
echo "============================================"
echo "HexRack SBC - STL Generation"
echo "============================================"
echo "Environment: $ENV_MODE"
echo "OpenSCAD:    $OPENSCAD"
echo "Version:     $OPENSCAD_VERSION"
if [ -n "$OPENSCAD_EXTRA_ARGS" ]; then
echo "Backend:     Manifold (fast)"
else
echo "Backend:     CGAL (default)"
fi
echo "Output:      $OUTPUT_DIR"
echo "Commit:      $COMMIT_HASH"
echo "============================================"
echo ""

# ============================================================================
# GENERATE BODY PARTS
# ============================================================================

echo "=== Body Parts ==="

# Function to run OpenSCAD with real-time logging
run_openscad() {
    local output_file="$1"
    local source_file="$2"
    shift 2
    local args=("$@")

    local part_name=$(basename "$output_file")
    local part_start=$(date +%s)

    TOTAL_PARTS=$((TOTAL_PARTS + 1))

    echo "    Command: $OPENSCAD $OPENSCAD_EXTRA_ARGS -o $output_file ${args[*]} $source_file"

    # Show memory before starting (CI only)
    if [ "$ENV_MODE" = "ci" ]; then
        echo "    Memory before: $(free -h 2>/dev/null | grep Mem | awk '{print $3 "/" $2}' || echo 'N/A')"
    fi

    # Run OpenSCAD with real-time output (no capture to file)
    # Using tee to show output AND capture exit code properly
    # --export-format=binstl outputs binary STL (5-10x smaller than ASCII)
    set +e  # Don't exit on error
    # shellcheck disable=SC2086
    "$OPENSCAD" $OPENSCAD_EXTRA_ARGS --export-format=binstl -o "$output_file" "${args[@]}" "$source_file" 2>&1 | while IFS= read -r line; do
        echo "    [OpenSCAD] $line"
    done
    local exit_code=${PIPESTATUS[0]}
    set -e

    local part_end=$(date +%s)
    local part_duration=$((part_end - part_start))

    if [ $exit_code -eq 0 ]; then
        echo "    ✓ Done in ${part_duration}s"
        SUCCESS_PARTS=$((SUCCESS_PARTS + 1))
        return 0
    else
        echo "    ✗ FAILED after ${part_duration}s (exit code: $exit_code)"
        # Decode common exit codes
        case $exit_code in
            137) echo "    → Exit 137: Process killed by SIGKILL (likely OOM - out of memory)" ;;
            143) echo "    → Exit 143: Process killed by SIGTERM (timeout or memory pressure)" ;;
            139) echo "    → Exit 139: Segmentation fault" ;;
            1)   echo "    → Exit 1: General error (check OpenSCAD output above)" ;;
            *)   echo "    → Unknown exit code" ;;
        esac
        # Show memory after failure (CI only)
        if [ "$ENV_MODE" = "ci" ]; then
            echo "    Memory after: $(free -h 2>/dev/null | grep Mem | awk '{print $3 "/" $2}' || echo 'N/A')"
        fi
        FAILED_PARTS="$FAILED_PARTS $part_name"
        return $exit_code
    fi
}

# Common overrides — never bake the antenna visualization into an STL.
COMMON_DEFS=(
    -D "show_sbc=false"
    -D "show_antennas=false"
)

# ============================================================================
# VARIANT MATRIX
# ============================================================================
# Face triples, bitmask expansion and naming live in their own file so they can be
# exercised by scripts/test-variant-matrix.sh without running a build.
# shellcheck source=lib/variant-matrix.sh
. "$(dirname "$0")/lib/variant-matrix.sh"

# ============================================================================
# MANIFEST ACCUMULATION
# ============================================================================
# Parts are recorded as they are generated rather than restated in a literal at
# the bottom of the file, so the manifest cannot drift from the loops above it.

PARTS_NDJSON="$(mktemp "${TMPDIR:-/tmp}/hexrack-parts.XXXXXX")"
trap 'rm -f "$PARTS_NDJSON"' EXIT

HAVE_JQ=false
if command -v jq &> /dev/null; then
    HAVE_JQ=true
elif [ "$GENERATE_MANIFEST" = true ]; then
    echo "❌ Error: jq is required to generate $MANIFEST_FILE"
    exit 1
else
    echo "ℹ️  jq not found — skipping manifest (not needed for local builds)"
fi

# Bytes and triangle count of a binary STL: 80-byte header, then a uint32 facet count.
# The website budgets its 3D preview off these, so they are measured from the artifact rather
# than estimated -- one part (feet) carries 93% of a case's triangles and must be identifiable.
stl_bytes()     { wc -c < "$1" | tr -d ' '; }
stl_triangles() { od -An -tu4 -j80 -N4 "$1" 2>/dev/null | tr -d ' \n'; }

# record_part <group> <id> <part> <name> <file> <options-json> [variant label] [exclude from zip]
#
# `part` is the stable slot a case is built from (dust|face|fan|feet|back-top|back-bottom|back-face)
# and `options` is the machine-readable axis assignment. Together they let the configurator answer
# "which file is the Back Face for THIS configuration" by comparison, never by parsing a filename
# or the human `variant` string -- which stays only for the gallery.
record_part() {
    if [ "$HAVE_JQ" != true ]; then return 0; fi
    local file="$OUTPUT_DIR/$5"
    jq -nc --arg g "$1" --arg i "$2" --arg p "$3" --arg n "$4" --arg f "$5" \
           --argjson o "$6" --arg v "${7:-}" --argjson x "${8:-false}" \
           --argjson b "$(stl_bytes "$file")" --argjson t "$(stl_triangles "$file")" \
       '{group:$g, id:$i, part:$p, name:$n, file:$f, options:$o, bytes:$b, triangles:$t}
        + (if $v == "" then {} else {variant:$v} end)
        + (if $x       then {excludeFromDownloadAll:true} else {} end)' \
       >> "$PARTS_NDJSON"
}

# ----------------------------------------------------------------------------
# Shared parts with no variant axis
# ----------------------------------------------------------------------------
# "<body_part>:<display name>" — one list, so adding a part cannot generate an STL
# the manifest never mentions.
for entry in "dust:Dust Filter" "fan:Fan Section" "feet:Feet"; do
    part="${entry%%:*}"
    label="${entry#*:}"
    echo "  → body-${part}.stl"
    if ! run_openscad "$OUTPUT_DIR/body-${part}.stl" "cad/body.scad" \
                "${COMMON_DEFS[@]}" \
                -D "enable_wifi_antennas=false" \
                -D "body_part=\"${part}\""; then
        echo "  ⚠ Warning: body-${part}.stl failed, continuing..."
        continue
    fi
    record_part "body-shared" "$part" "$part" "$label" "body-${part}.stl" '{}'
done

# ----------------------------------------------------------------------------
# Face — vent pattern crossed with the front circle
# ----------------------------------------------------------------------------
# The default combination keeps the bare body-face.stl name so existing links and the
# showcase do not break; every other combination is suffixed.
for pattern in "${FACE_VENT_PATTERNS[@]}"; do
    for circle in true false; do
        psuffix=""; plabel=""
        if [ "$pattern" != "$DEFAULT_VENT_PATTERN" ]; then
            psuffix="-$pattern"; plabel="Vent: $pattern"
        fi
        if [ "$circle" = true ]; then
            csuffix=""; clabel=""
        else
            csuffix="-nocircle"; clabel="No front circle"
        fi

        file="body-face${psuffix}${csuffix}.stl"
        id="face${psuffix}${csuffix}"
        if [ -n "$plabel" ] && [ -n "$clabel" ]; then variant="$plabel — $clabel"
        elif [ -n "$plabel" ];                   then variant="$plabel"
        else                                          variant="$clabel"
        fi
        if [ "$pattern" = "$DEFAULT_VENT_PATTERN" ] && [ "$circle" = true ]; then
            exclude=false
        else
            exclude=true
        fi

        echo "  → $file"
        if ! run_openscad "$OUTPUT_DIR/$file" "cad/body.scad" \
                    "${COMMON_DEFS[@]}" \
                    -D "enable_wifi_antennas=false" \
                    -D "enable_front_circle=$circle" \
                    -D "face_vent_pattern=\"$pattern\"" \
                    -D "body_part=\"face\""; then
            echo "  ⚠ Warning: $file failed, continuing..."
            continue
        fi
        record_part "body-shared" "$id" "face" "Face" "$file" \
            "$(jq -nc --arg p "$pattern" --argjson c "$circle" \
                '{ventPattern:$p, frontCircle:$c}')" \
            "$variant" "$exclude"
    done
done

# ----------------------------------------------------------------------------
# Back top — the eight male dovetail combinations
# ----------------------------------------------------------------------------
for mask in $DOVETAIL_MASKS; do
    code=$(dovetail_code "$mask" "${MALE_FACES[@]}")
    defn=$(dovetail_defn "$mask" "${MALE_FACES[@]}")
    if [ "$mask" -eq "$ALL_MASK" ]; then
        id="back-top"; file="body-back-top.stl"
        group="body-shared"; variant=""; exclude=false
    else
        id="back-top-$code"; file="body-back-top-$code.stl"
        group="dovetails-shared"
        variant="Dovetails: $(dovetail_label "$mask" "${MALE_FACES[@]}")"
        exclude=true
    fi
    echo "  → $file"
    if ! run_openscad "$OUTPUT_DIR/$file" "cad/body.scad" \
                "${COMMON_DEFS[@]}" \
                -D "enable_wifi_antennas=false" \
                -D "$defn" \
                -D "body_part=\"back-top\""; then
        echo "  ⚠ Warning: $file failed, continuing..."
        continue
    fi
    record_part "$group" "$id" "back-top" "Back Top" "$file" \
        "$(jq -nc --argjson d "$(dovetail_faces_json "$mask" "${MALE_FACES[@]}")" \
            '{dovetails:$d}')" \
        "$variant" "$exclude"
done

# ----------------------------------------------------------------------------
# SBC-specific back parts
# ----------------------------------------------------------------------------
for board in rock5b+ rpi5_pironman; do
    case "$board" in
        rock5b+)       bkey="rock5b"   ;;
        rpi5_pironman) bkey="pironman" ;;
        # Without this arm an unmatched board keeps the previous iteration's key and
        # quietly files its parts under the wrong board.
        *) echo "❌ Error: no manifest key for board '$board'"; exit 1 ;;
    esac
    group="body-$bkey"
    dgroup="dovetails-$bkey"

    echo "  Board: $board"

    # Back bottom — the eight female dovetail combinations.
    #
    # PAIRING: back-bottom and back-face must be printed with the SAME mask. The back
    # face's front lip refills the last 3mm of every groove that is not carried through
    # it (see back-face.scad), so a mismatched pair leaves a groove a neighbour's rail
    # cannot enter. The shared filename code is what pairs them: -b-bl goes with -b-bl.
    for mask in $DOVETAIL_MASKS; do
        code=$(dovetail_code "$mask" "${FEMALE_FACES[@]}")
        defn=$(dovetail_defn "$mask" "${FEMALE_FACES[@]}")
        if [ "$mask" -eq "$ALL_MASK" ]; then
            id="back-bottom-$bkey"; file="body-back-bottom-${board}.stl"
            g="$group"; variant=""; exclude=false
        else
            id="back-bottom-$bkey-$code"; file="body-back-bottom-${board}-${code}.stl"
            g="$dgroup"
            variant="Dovetails (match Back Face): $(dovetail_label "$mask" "${FEMALE_FACES[@]}")"
            exclude=true
        fi
        echo "    → $file"
        if ! run_openscad "$OUTPUT_DIR/$file" "cad/body.scad" \
                    "${COMMON_DEFS[@]}" \
                    -D "enable_wifi_antennas=false" \
                    -D "$defn" \
                    -D "body_part=\"back-bottom\"" \
                    -D "drawer_board=\"${board}\""; then
            echo "    ⚠ Warning: $file failed, continuing..."
            continue
        fi
        record_part "$g" "$id" "back-bottom" "Back Bottom" "$file" \
            "$(jq -nc --arg b "$board" \
                      --argjson d "$(dovetail_faces_json "$mask" "${FEMALE_FACES[@]}")" \
                '{board:$b, dovetails:$d}')" \
            "$variant" "$exclude"
    done

    # Back face — antennas x female dovetails x vent pattern.
    #
    # The vent axis is here because back-face.scad:68 calls the same ventPatternCutter as the
    # face does, so the back panel silently follows face_vent_pattern. It cannot follow it all
    # the way: at back_face_thickness=3 a gyroid sweeps 135 degrees of lattice and trips the
    # closed-form solver's assert, hence back_face_vent().
    for ant in false true; do
        if [ "$ant" = true ]; then
            asuffix="-antennas"; alabel="WiFi Antennas"
        else
            asuffix=""; alabel=""
        fi
      # Over the back face's own distinct patterns, NOT over the face's -- see
      # back_face_patterns(). Two face patterns sharing a back panel share the file.
      for bf_pattern in $(back_face_patterns); do
        if [ "$bf_pattern" != "$DEFAULT_VENT_PATTERN" ]; then
            psuffix="-$bf_pattern"; plabel="Vent: $bf_pattern"
        else
            psuffix=""; plabel=""
        fi
        for mask in $DOVETAIL_MASKS; do
            code=$(dovetail_code "$mask" "${FEMALE_FACES[@]}")
            defn=$(dovetail_defn "$mask" "${FEMALE_FACES[@]}")
            if [ "$mask" -eq "$ALL_MASK" ]; then
                dsuffix=""; dlabel=""; g="$group"
            else
                dsuffix="-$code"
                dlabel="Dovetails (match Back Bottom): $(dovetail_label "$mask" "${FEMALE_FACES[@]}")"
                g="$dgroup"
            fi

            file="body-back-face-${board}${asuffix}${psuffix}${dsuffix}.stl"
            id="back-face-${bkey}${asuffix}${psuffix}${dsuffix}"

            variant=""
            for piece in "$alabel" "$plabel" "$dlabel"; do
                [ -n "$piece" ] && variant="${variant:+$variant — }$piece"
            done

            # Only the plain, all-faces, default-pattern panel belongs in the bulk zip;
            # every other combination is an alternative the user picks deliberately.
            if [ "$ant" = true ] || [ "$mask" -ne "$ALL_MASK" ] || [ -n "$psuffix" ]; then
                exclude=true
            else
                exclude=false
            fi

            echo "    → $file"
            if ! run_openscad "$OUTPUT_DIR/$file" "cad/body.scad" \
                        "${COMMON_DEFS[@]}" \
                        -D "enable_wifi_antennas=$ant" \
                        -D "$defn" \
                        -D "face_vent_pattern=\"$bf_pattern\"" \
                        -D "body_part=\"back-face\"" \
                        -D "drawer_board=\"${board}\""; then
                echo "    ⚠ Warning: $file failed, continuing..."
                continue
            fi
            record_part "$g" "$id" "back-face" "Back Face" "$file" \
                "$(jq -nc --arg b "$board" --arg p "$bf_pattern" --argjson a "$ant" \
                          --argjson d "$(dovetail_faces_json "$mask" "${FEMALE_FACES[@]}")" \
                    '{board:$b, ventPattern:$p, antennas:$a, dovetails:$d}')" \
                "$variant" "$exclude"
        done
      done
    done
done

# Per-board assemblies (used by showcase) — base variant only, no antennas baked in
for board in rock5b+ rpi5_pironman; do
    echo "  → body-assembly-${board}.stl"
    if ! run_openscad "$OUTPUT_DIR/body-assembly-${board}.stl" "cad/body.scad" \
                "${COMMON_DEFS[@]}" \
                -D "enable_wifi_antennas=false" \
                -D "body_part=\"assembly\"" \
                -D "bodyAssembly_space=0" \
                -D "drawer_board=\"${board}\""; then
        echo "  ⚠ Warning: body-assembly-${board}.stl failed, continuing..."
    fi
done

# Showcase: 3-unit honeycomb stack
echo ""
echo "=== Showcase ==="
echo "  → showcase.stl"
if ! run_openscad "$OUTPUT_DIR/showcase.stl" "cad/showcase.scad" \
            -D "stl_path=\"../${OUTPUT_DIR}\""; then
    echo "  ⚠ Warning: showcase.stl failed, continuing..."
fi
# ============================================================================
# GENERATE MANIFEST (CI only)
# ============================================================================

if [ "$GENERATE_MANIFEST" = true ]; then
    echo ""
    echo "=== Generating Manifest ==="

    mkdir -p "$(dirname "$MANIFEST_FILE")"

    # Group presentation order and copy. Groups that end up with no parts are
    # dropped, so this list can describe more than a given run produces.
    GROUPS_META='[
      { "id": "body-shared",
        "name": "Body (Shared)",
        "description": "Common parts for all configurations. The Face ships with the front circle traced across the pattern; take the plain variant if you prefer it uninterrupted." },
      { "id": "body-rock5b",
        "name": "Back: Rock5B+",
        "description": "Back panels for Rock5B+ board. Pick one Back Face — base or WiFi antennas." },
      { "id": "body-pironman",
        "name": "Back: RPi5 Pironman",
        "description": "Back panels for Raspberry Pi 5 Pironman. Pick one Back Face — base or WiFi antennas." },
      { "id": "dovetails-shared",
        "name": "Intercase Dovetails (Shared)",
        "description": "Alternative Back Top halves for cases that do not present all three upward faces to a neighbour. Take the default from Body (Shared) unless you are tiling a wall." },
      { "id": "dovetails-rock5b",
        "name": "Intercase Dovetails: Rock5B+",
        "description": "Alternative Back Bottom and Back Face halves for cases that do not receive a neighbour on all three downward faces. Print the two with the SAME dovetail code — a Back Face that does not carry a groove through seals it shut on the Back Bottom." },
      { "id": "dovetails-pironman",
        "name": "Intercase Dovetails: RPi5 Pironman",
        "description": "Alternative Back Bottom and Back Face halves for cases that do not receive a neighbour on all three downward faces. Print the two with the SAME dovetail code — a Back Face that does not carry a groove through seals it shut on the Back Bottom." }
    ]'

    # ------------------------------------------------------------------------
    # Axis declaration.
    #
    # The configurator's controls are BUILT FROM this, never from enums hardcoded in
    # TypeScript. A pattern that is not built therefore cannot be offered, and one that
    # starts being built appears on the site with no frontend change -- which is how
    # gyroid will arrive (see epic 0b in plan/2026-09-02-rack-configurator.md).
    AXES=$(jq -nc \
        --argjson vent "$(printf '%s\n' "${FACE_VENT_PATTERNS[@]}" | jq -R . | jq -sc .)" \
        --arg    vdef "$DEFAULT_VENT_PATTERN" \
        --argjson male "$(printf '%s\n' "${MALE_FACES[@]}" | jq -R . | jq -sc .)" \
        --argjson female "$(printf '%s\n' "${FEMALE_FACES[@]}" | jq -R . | jq -sc .)" \
        '{
           board: { values: ["rock5b+", "rpi5_pironman"],
                    labels: { "rock5b+": "Rock 5B+", "rpi5_pironman": "RPi 5 · Pironman" } },
           ventPattern: { values: $vent, default: $vdef,
                          # Patterns the BACK face cannot carry, and what it uses instead.
                          # Empty while gyroid is out of the build; the client must apply it
                          # rather than reimplement the rule.
                          backFaceFallback: { gyroid: "triangles" } },
           frontCircle: { values: [true, false], default: true },
           antennas:    { values: [false, true], default: false },
           faces: { male: $male, female: $female,
                    # bit i of either triple names a MATING PAIR under the hex tiling
                    mates: { top: "bottom", "top-right": "bottom-left", "top-left": "bottom-right",
                             bottom: "top", "bottom-left": "top-right", "bottom-right": "top-left" } }
         }')

    # ------------------------------------------------------------------------
    # Geometry + assembly layout, so the site can compose a preview of the user's actual
    # configuration from its resolved parts. No pre-baked assembly can do that: the ones
    # this script builds are fixed at antennas-off, default mask, default pattern.
    #
    # READ FROM THE CAD, not written here. These were literals until face_depth stopped
    # being one -- it is now derived from the gyroid's cell size, so it moves whenever
    # that does, and a hardcoded copy would have gone stale silently.
    # --export-format=echo writes the echoes INTO the output file, so this needs a real
    # path -- /dev/null silently discards them and yields an empty layout.
    #
    # And the path must be IN-TREE. OpenSCAD installed from snap is strictly confined and
    # gets a private /tmp, so a file under the host's /tmp is invisible to it: it writes
    # nothing, the layout comes back empty, and the build fails at the manifest. Same
    # constraint the test scripts document for their work directories.
    LAYOUT_TMP="$(mktemp "./.test-work.layout.XXXXXX")"
    "$OPENSCAD" -o "$LAYOUT_TMP" --export-format=echo cad/layout-export.scad > /dev/null 2>&1
    LAYOUT_ECHO=$(grep -o 'HEXRACK_LAYOUT[^"]*' "$LAYOUT_TMP" | head -1)
    rm -f "$LAYOUT_TMP"
    if [ -z "$LAYOUT_ECHO" ]; then
        echo "❌ Error: cad/layout-export.scad emitted no layout"
        exit 1
    fi
    lay() { printf '%s' "$LAYOUT_ECHO" | tr ' ' '\n' | sed -n "s/^$1=//p"; }

    LAYOUT=$(jq -nc \
        --argjson p2p  "$(lay pointToPoint)" --argjson f2f  "$(lay flatToFlat)" \
        --argjson cd   "$(lay caseDepth)"    --argjson dust "$(lay dust)" \
        --argjson face "$(lay face)"         --argjson fan  "$(lay fan)" \
        --argjson bb   "$(lay backBottom)"   --argjson bt   "$(lay backTop)" \
        --argjson bf   "$(lay backFace)"     --argjson fd   "$(lay feetDrop)" \
        --argjson cp   "$(lay columnPitch)"  --argjson rp   "$(lay rowPitch)" \
        '{
           units: "mm",
           hex: { pointToPoint: $p2p, flatToFlat: $f2f, orientation: "flat-top" },
           # centre(q,r) = [ columnPitch*q , rowPitch*(r + q/2) ]  in the XZ plane
           gridPitch: { column: $cp, row: $rp, columnStagger: ($rp / 2) },
           caseDepth: $cd,
           partOffsetY: { dust: $dust, face: $face, fan: $fan,
                          "back-bottom": $bb, "back-top": $bt, "back-face": $bf },
           # A foot bridges a half-column offset; it drops exactly flatToFlat/2.
           feet: { drop: $fd,
                   rule: "ground units only, and only those above the lowest ground unit" }
         }')

    # Fasteners actually consumed by the CAD. NOT the readme list, which names M3-16
    # (used nowhere) and omits the M4 stack screws and the M2.5 inserts entirely.
    HARDWARE=$(jq -nc '[
        { id: "fan",     name: "Noctua NF-A9 PWM 92mm", perUnit: 1 },
        { id: "m4-50",   name: "M4×50 + M4 nut traps — face/dust/fan/back stack", perUnit: 4 },
        { id: "m3-10",   name: "M3×10 — back panel joins", perUnit: 8 },
        { id: "m5",      name: "M5 — Noctua fan mount", perUnit: 4 },
        { id: "m2.5-4",  name: "M2.5×4 + heat-set inserts — SBC standoffs", perUnit: 4 },
        { id: "antenna", name: "SMA post + 8mm-AF nut", perUnit: 0, perAntennaUnit: 2 }
      ]')

    jq -n \
        --arg generated "$GENERATED_AT" \
        --arg commit "$COMMIT_HASH" \
        --argjson meta "$GROUPS_META" \
        --argjson axes "$AXES" \
        --argjson layout "$LAYOUT" \
        --argjson hardware "$HARDWARE" \
        --slurpfile parts "$PARTS_NDJSON" \
        '{
           schemaVersion: 2,
           generated: $generated,
           commit: $commit,
           assemblies: { body: "showcase.stl" },
           axes: $axes,
           layout: $layout,
           hardware: $hardware,
           # Flat, machine-readable. The configurator resolves against this and never
           # parses a filename or the human `variant` string.
           parts: [ $parts[] | del(.group) ],
           # Kept so the existing gallery keeps working unchanged during the rebuild.
           groups: [
             $meta[] as $g
             | { id: $g.id, name: $g.name, description: $g.description,
                 parts: [ $parts[] | select(.group == $g.id) | del(.group) ] }
             | select(.parts | length > 0)
           ]
         }' > "$MANIFEST_FILE"

    echo "  → $MANIFEST_FILE"

    # --- Drift check --------------------------------------------------------
    # The manifest is what the website reads, so a name that does not resolve is
    # a broken download button. Fail the build rather than ship one.
    MANIFEST_ERRORS=0

    while IFS= read -r part_file; do
        if [ ! -s "$OUTPUT_DIR/$part_file" ]; then
            echo "  ✗ manifest references a missing or empty file: $part_file"
            MANIFEST_ERRORS=$((MANIFEST_ERRORS + 1))
        fi
    done < <(jq -r '.parts[].file' "$MANIFEST_FILE")

    # Assemblies and the showcase are referenced separately, not as parts.
    for stl in "$OUTPUT_DIR"/*.stl; do
        # An empty output directory leaves the glob unexpanded; skip the literal.
        [ -e "$stl" ] || continue
        stl_name=$(basename "$stl")
        case "$stl_name" in
            showcase.stl|body-assembly-*) continue ;;
        esac
        if ! jq -e --arg f "$stl_name" \
                'any(.parts[]; .file == $f)' "$MANIFEST_FILE" > /dev/null; then
            echo "  ✗ generated but absent from the manifest: $stl_name"
            echo "      (usually a record_part group id with no entry in GROUPS_META)"
            MANIFEST_ERRORS=$((MANIFEST_ERRORS + 1))
        fi
    done

    # --- Completeness check -------------------------------------------------
    # Stronger than the drift check above, and the one that matters for a configurator:
    # EVERY combination the UI can express must resolve to exactly one part. The UI is
    # generated from .axes, so this walks the same cross-product the user can reach and
    # fails the build if any cell is missing or ambiguous.
    if ! ./scripts/test-manifest.sh "$MANIFEST_FILE"; then
        MANIFEST_ERRORS=$((MANIFEST_ERRORS + 1))
    fi

    if [ "$MANIFEST_ERRORS" -gt 0 ]; then
        echo "  ✗ Manifest validation failed ($MANIFEST_ERRORS broken reference(s))"
    else
        echo "  ✓ Manifest validated ($(jq '[.groups[].parts[]] | length' "$MANIFEST_FILE") parts)"
    fi
fi

# ============================================================================
# SUMMARY
# ============================================================================

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

STL_COUNT=$(ls -1 "$OUTPUT_DIR"/*.stl 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "============================================"
if [ -z "$FAILED_PARTS" ]; then
    echo "✅ Generation Complete!"
else
    echo "⚠️  Generation Complete (with failures)"
fi
echo "============================================"
echo "Time:    ${MINUTES}m ${SECONDS}s"
echo "Files:   $STL_COUNT STL files generated"
echo "Success: $SUCCESS_PARTS / $TOTAL_PARTS parts"
echo "Output:  $OUTPUT_DIR"
if [ -n "$FAILED_PARTS" ]; then
    echo ""
    echo "❌ Failed parts:$FAILED_PARTS"
fi
echo ""

if [ "$MANIFEST_ERRORS" -gt 0 ]; then
    echo "❌ Manifest validation failed ($MANIFEST_ERRORS broken reference(s))"
    echo ""
fi

# Exit with error if any part failed or the manifest does not resolve (for CI)
if [ -n "$FAILED_PARTS" ] || [ "$MANIFEST_ERRORS" -gt 0 ]; then
    exit 1
fi

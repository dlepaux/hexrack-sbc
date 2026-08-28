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

# record_part <group> <id> <name> <file> [variant label] [exclude from zip]
record_part() {
    if [ "$HAVE_JQ" != true ]; then return 0; fi
    jq -nc --arg g "$1" --arg i "$2" --arg n "$3" --arg f "$4" \
           --arg v "${5:-}" --argjson x "${6:-false}" \
       '{group:$g, id:$i, name:$n, file:$f}
        + (if $v == "" then {} else {variant:$v} end)
        + (if $x       then {excludeFromDownloadAll:true} else {} end)' \
       >> "$PARTS_NDJSON"
}

# ----------------------------------------------------------------------------
# Shared parts with no variant axis
# ----------------------------------------------------------------------------
for part in dust fan feet; do
    echo "  → body-${part}.stl"
    if ! run_openscad "$OUTPUT_DIR/body-${part}.stl" "cad/body.scad" \
                "${COMMON_DEFS[@]}" \
                -D "enable_wifi_antennas=false" \
                -D "body_part=\"${part}\""; then
        echo "  ⚠ Warning: body-${part}.stl failed, continuing..."
    fi
done
record_part "body-shared" "dust" "Dust Filter" "body-dust.stl"
record_part "body-shared" "fan"  "Fan Section" "body-fan.stl"
record_part "body-shared" "feet" "Feet"        "body-feet.stl"

# ----------------------------------------------------------------------------
# Face — front circle on/off
# ----------------------------------------------------------------------------
for circle in true false; do
    if [ "$circle" = true ]; then
        id="face"; file="body-face.stl"; variant=""; exclude=false
    else
        id="face-nocircle"; file="body-face-nocircle.stl"
        variant="No front circle"; exclude=true
    fi
    echo "  → $file"
    if ! run_openscad "$OUTPUT_DIR/$file" "cad/body.scad" \
                "${COMMON_DEFS[@]}" \
                -D "enable_wifi_antennas=false" \
                -D "enable_front_circle=$circle" \
                -D "body_part=\"face\""; then
        echo "  ⚠ Warning: $file failed, continuing..."
    fi
    record_part "body-shared" "$id" "Face" "$file" "$variant" "$exclude"
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
    fi
    record_part "$group" "$id" "Back Top" "$file" "$variant" "$exclude"
done

# ----------------------------------------------------------------------------
# SBC-specific back parts
# ----------------------------------------------------------------------------
for board in rock5b+ rpi5_pironman; do
    case "$board" in
        rock5b+)       bkey="rock5b"   ;;
        rpi5_pironman) bkey="pironman" ;;
    esac
    group="body-$bkey"
    dgroup="dovetails-$bkey"

    echo "  Board: $board"

    # Top supports — dovetail-agnostic
    file="body-top-supports-${board}.stl"
    echo "    → $file"
    if ! run_openscad "$OUTPUT_DIR/$file" "cad/body.scad" \
                "${COMMON_DEFS[@]}" \
                -D "enable_wifi_antennas=false" \
                -D "body_part=\"top-supports\"" \
                -D "drawer_board=\"${board}\""; then
        echo "    ⚠ Warning: $file failed, continuing..."
    fi
    record_part "$group" "top-supports-$bkey" "Top Supports" "$file"

    # Back bottom — the eight female dovetail combinations
    for mask in $DOVETAIL_MASKS; do
        code=$(dovetail_code "$mask" "${FEMALE_FACES[@]}")
        defn=$(dovetail_defn "$mask" "${FEMALE_FACES[@]}")
        if [ "$mask" -eq "$ALL_MASK" ]; then
            id="back-bottom-$bkey"; file="body-back-bottom-${board}.stl"
            g="$group"; variant=""; exclude=false
        else
            id="back-bottom-$bkey-$code"; file="body-back-bottom-${board}-${code}.stl"
            g="$dgroup"
            variant="Dovetails: $(dovetail_label "$mask" "${FEMALE_FACES[@]}")"
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
        fi
        record_part "$g" "$id" "Back Bottom" "$file" "$variant" "$exclude"
    done

    # Back face — antenna axis crossed with the female dovetail axis
    for ant in false true; do
        if [ "$ant" = true ]; then
            asuffix="-antennas"; alabel="WiFi Antennas"
        else
            asuffix=""; alabel=""
        fi
        for mask in $DOVETAIL_MASKS; do
            code=$(dovetail_code "$mask" "${FEMALE_FACES[@]}")
            defn=$(dovetail_defn "$mask" "${FEMALE_FACES[@]}")
            if [ "$mask" -eq "$ALL_MASK" ]; then
                dsuffix=""; dlabel=""; g="$group"
            else
                dsuffix="-$code"
                dlabel="Dovetails: $(dovetail_label "$mask" "${FEMALE_FACES[@]}")"
                g="$dgroup"
            fi

            file="body-back-face-${board}${asuffix}${dsuffix}.stl"
            id="back-face-${bkey}${asuffix}${dsuffix}"

            if [ -n "$alabel" ] && [ -n "$dlabel" ]; then
                variant="$alabel — $dlabel"
            elif [ -n "$alabel" ]; then
                variant="$alabel"
            else
                variant="$dlabel"
            fi

            # Only the plain, all-faces panel belongs in the bulk zip; every other
            # combination is an alternative the user picks deliberately.
            if [ "$ant" = true ] || [ "$mask" -ne "$ALL_MASK" ]; then
                exclude=true
            else
                exclude=false
            fi

            echo "    → $file"
            if ! run_openscad "$OUTPUT_DIR/$file" "cad/body.scad" \
                        "${COMMON_DEFS[@]}" \
                        -D "enable_wifi_antennas=$ant" \
                        -D "$defn" \
                        -D "body_part=\"back-face\"" \
                        -D "drawer_board=\"${board}\""; then
                echo "    ⚠ Warning: $file failed, continuing..."
            fi
            record_part "$g" "$id" "Back Face" "$file" "$variant" "$exclude"
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
        "description": "Alternative Back Bottom and Back Face halves for cases that do not receive a neighbour on all three downward faces." },
      { "id": "dovetails-pironman",
        "name": "Intercase Dovetails: RPi5 Pironman",
        "description": "Alternative Back Bottom and Back Face halves for cases that do not receive a neighbour on all three downward faces." }
    ]'

    jq -n \
        --arg generated "$GENERATED_AT" \
        --arg commit "$COMMIT_HASH" \
        --argjson meta "$GROUPS_META" \
        --slurpfile parts "$PARTS_NDJSON" \
        '{
           generated: $generated,
           commit: $commit,
           assemblies: { body: "showcase.stl" },
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
    done < <(jq -r '.groups[].parts[].file' "$MANIFEST_FILE")

    # Assemblies and the showcase are referenced separately, not as parts.
    for stl in "$OUTPUT_DIR"/*.stl; do
        stl_name=$(basename "$stl")
        case "$stl_name" in
            showcase.stl|body-assembly-*) continue ;;
        esac
        if ! jq -e --arg f "$stl_name" \
                'any(.groups[].parts[]; .file == $f)' "$MANIFEST_FILE" > /dev/null; then
            echo "  ⚠ generated but absent from the manifest: $stl_name"
        fi
    done

    if [ "$MANIFEST_ERRORS" -gt 0 ]; then
        echo "  ✗ Manifest validation failed ($MANIFEST_ERRORS broken reference(s))"
        exit 1
    fi

    echo "  ✓ Manifest validated ($(jq '[.groups[].parts[]] | length' "$MANIFEST_FILE") parts)"
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

# Exit with error if any parts failed (for CI)
if [ -n "$FAILED_PARTS" ]; then
    exit 1
fi

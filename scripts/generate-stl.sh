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

# Shared parts (SBC-independent)
for part in face dust fan feet back-top; do
    echo "  → body-${part}.stl"
    if ! run_openscad "$OUTPUT_DIR/body-${part}.stl" "cad/body.scad" \
                -D "show_sbc=false" \
                -D "body_part=\"${part}\""; then
        echo "  ⚠ Warning: body-${part}.stl failed, continuing..."
    fi
done

# SBC-specific back parts
for board in rock5b+ rpi5_pironman; do
    echo "  Board: $board"
    for part in back-bottom back-face top-supports; do
        echo "    → body-${part}-${board}.stl"
        if ! run_openscad "$OUTPUT_DIR/body-${part}-${board}.stl" "cad/body.scad" \
                    -D "show_sbc=false" \
                    -D "body_part=\"${part}\"" \
                    -D "drawer_board=\"${board}\""; then
            echo "    ⚠ Warning: body-${part}-${board}.stl failed, continuing..."
        fi
    done
done

# Per-board assemblies (used by showcase)
for board in rock5b+ rpi5_pironman; do
    echo "  → body-assembly-${board}.stl"
    if ! run_openscad "$OUTPUT_DIR/body-assembly-${board}.stl" "cad/body.scad" \
                -D "show_sbc=false" \
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
    
    cat > "$MANIFEST_FILE" << EOF
{
  "generated": "$GENERATED_AT",
  "commit": "$COMMIT_HASH",
  "assemblies": {
    "body": "showcase.stl"
  },
  "groups": [
    {
      "id": "body-shared",
      "name": "Body (Shared)",
      "description": "Common parts for all configurations",
      "parts": [
        { "id": "face", "name": "Face", "file": "body-face.stl" },
        { "id": "dust", "name": "Dust Filter", "file": "body-dust.stl" },
        { "id": "feet", "name": "Feet", "file": "body-feet.stl" },
        { "id": "fan", "name": "Fan Section", "file": "body-fan.stl" },
        { "id": "back-top", "name": "Back Top", "file": "body-back-top.stl" }
      ]
    },
    {
      "id": "body-rock5b",
      "name": "Back: Rock5B+",
      "description": "Back panels for Rock5B+ board",
      "parts": [
        { "id": "back-bottom-rock5b", "name": "Back Bottom", "file": "body-back-bottom-rock5b+.stl" },
        { "id": "back-face-rock5b", "name": "Back Face", "file": "body-back-face-rock5b+.stl" },
        { "id": "top-supports-rock5b", "name": "Top Supports", "file": "body-top-supports-rock5b+.stl" }
      ]
    },
    {
      "id": "body-pironman",
      "name": "Back: RPi5 Pironman",
      "description": "Back panels for Raspberry Pi 5 Pironman",
      "parts": [
        { "id": "back-bottom-pironman", "name": "Back Bottom", "file": "body-back-bottom-rpi5_pironman.stl" },
        { "id": "back-face-pironman", "name": "Back Face", "file": "body-back-face-rpi5_pironman.stl" },
        { "id": "top-supports-pironman", "name": "Top Supports", "file": "body-top-supports-rpi5_pironman.stl" }
      ]
    }
  ]
}
EOF
    
    echo "  → $MANIFEST_FILE"
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

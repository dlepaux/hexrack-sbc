#!/bin/bash

# ============================================================================
# HexRack SBC - OpenSCAD WebAssembly fetch
# ============================================================================
# The configurator engraves per-unit labels IN THE BROWSER: a Web Worker runs real
# OpenSCAD, compiled to wasm, over this repo's own cad/ sources with the label passed
# as -D. The binary is ~11MB, so it is fetched at build time rather than committed.
#
# Deliberately NOT an npm postinstall hook: an unrelated `npm ci` should not pull 3MB.
# Run it once before `npm run dev`; CI runs it as its own step.
#
# Usage: ./scripts/fetch-openscad-wasm.sh
# ============================================================================

set -e

# Pinned by DIGEST, and the digest is the only thing that makes this URL trustworthy: the
# artifact is fetched over the network into a directory the site serves as executable code.
#
# files.openscad.org/snapshots/ has no "latest" alias and no retention guarantee — it lists
# 209 WebAssembly-web snapshots today, back to 2024.12.08, and this one can disappear. When
# it 404s the fix is a newer snapshot, its published .sha256, and a re-run of
# scripts/test-dust-label.sh against it, all in one commit. Do not reach for
# github.com/openscad/openscad-wasm instead: its last release is from 2022 and predates the
# textmetrics builtin the label width assert depends on.
#
# Must be the -web build. It is an ES module (`export default OpenSCAD`) the Worker imports;
# the -node zip of the same snapshot is not loadable in a browser.
VERSION="2026.09.01"
URL="https://files.openscad.org/snapshots/OpenSCAD-${VERSION}-WebAssembly-web.zip"
SHA256="a39c3cec28c4135cbbffaa3798065b182b42a4e6e2bf64cead91af8448f8d641"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/public/wasm"

# Idempotent, so it is safe in front of every dev server start and every CI run.
if [ -s "$DEST/openscad.js" ] && [ -s "$DEST/openscad.wasm" ]; then
    echo "✅ OpenSCAD wasm already in public/wasm — nothing to fetch"
    exit 0
fi

# macOS ships shasum, Linux CI ships sha256sum; same split the rest of scripts/ lives with.
sha256_of() {
    if command -v sha256sum &> /dev/null; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "⬇️  Fetching OpenSCAD $VERSION (WebAssembly, web)"
curl -fsSL -o "$TMP/openscad-wasm.zip" "$URL"

GOT="$(sha256_of "$TMP/openscad-wasm.zip")"
if [ "$GOT" != "$SHA256" ]; then
    echo "❌ Checksum mismatch — refusing to unpack"
    echo "   url      $URL"
    echo "   expected $SHA256"
    echo "   got      $GOT"
    echo ""
    echo "   Either the snapshot was replaced in place or the download was tampered with."
    echo "   Verify against the published .sha256 before changing the pin above."
    exit 1
fi

# The two members are named explicitly rather than extracted wholesale, so a future archive
# that grows extra files cannot quietly drop them into a directory the site serves.
mkdir -p "$DEST"
unzip -q -o -j "$TMP/openscad-wasm.zip" openscad.js openscad.wasm -d "$DEST"

echo "✅ public/wasm/openscad.js ($(wc -c < "$DEST/openscad.js" | tr -d ' ') bytes)"
echo "✅ public/wasm/openscad.wasm ($(wc -c < "$DEST/openscad.wasm" | tr -d ' ') bytes)"

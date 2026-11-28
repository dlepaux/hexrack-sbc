#!/bin/bash

# ============================================================================
# PRUNED TREE - the cad/ subset the website's engrave worker mounts
# ============================================================================
# The site engraves the dust filter in-page with OpenSCAD-wasm, mounting only
# cad/**/*.{scad,cfg} minus the SBC_Model_Framework submodule and cad/assets/, with two
# zero-byte stubs standing in for the submodule files dust.scad include/uses. Tests that
# compare a render from this tree against the full one build it here, from the RULE
# rather than a file list, so they cannot drift from what the worker ships or from each
# other.

# build_pruned_tree <repo root> <destination>: writes <destination>/cad/.
build_pruned_tree() {
    local root="$1" dest="$2" f
    while IFS= read -r f; do
        mkdir -p "$dest/cad/$(dirname "$f")"
        cp "$root/cad/$f" "$dest/cad/$f"
    done < <(cd "$root/cad" && find . -type f \( -name '*.scad' -o -name '*.cfg' \) \
                 -not -path './SBC_Model_Framework/*' -not -path './assets/*' | sed 's|^\./||')
    mkdir -p "$dest/cad/SBC_Model_Framework"
    : > "$dest/cad/SBC_Model_Framework/sbc_models.scad"
    : > "$dest/cad/SBC_Model_Framework/sbc_models.cfg"
}

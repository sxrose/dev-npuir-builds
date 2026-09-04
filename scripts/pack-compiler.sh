#!/usr/bin/env bash

set -euo pipefail

IR_ROOT="${IR_ROOT:-/workspace/AscendNPU-IR}"
BUILD_DIR="${BUILD_DIR:-build-ubuntu20}"
INSTALL_DIR="$IR_ROOT/$BUILD_DIR/install"
OUTPUT="${1:-$IR_ROOT/$BUILD_DIR/bishengir-compiler.tar.zst}"

[[ -x "$INSTALL_DIR/bin/bishengir-compile" ]] || {
  printf 'Compiler not found: %s\n' "$INSTALL_DIR/bin/bishengir-compile" >&2
  printf 'Run build-compiler first.\n' >&2
  exit 1
}

shopt -s nullglob
BC_FILES=("$INSTALL_DIR"/lib/*.bc)
(( ${#BC_FILES[@]} > 0 )) || {
  printf 'No bitcode files found in: %s\n' "$INSTALL_DIR/lib" >&2
  exit 1
}

mkdir -p "$(dirname "$OUTPUT")"
ARCHIVE_FILES=(bin/bishengir-compile)
for bc_file in "${BC_FILES[@]}"; do
  ARCHIVE_FILES+=("lib/$(basename "$bc_file")")
done

tar --zstd -cf "$OUTPUT" -C "$INSTALL_DIR" "${ARCHIVE_FILES[@]}"

printf 'Created %s\n' "$OUTPUT"

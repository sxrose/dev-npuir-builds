#!/usr/bin/env bash

set -euo pipefail

IR_ROOT="${IR_ROOT:-/workspace/AscendNPU-IR}"
BUILD_DIR="${BUILD_DIR:-build-ubuntu20}"
CANN_PATH="${CANN_PATH:-/usr/local/Ascend/cann}"

cd "$IR_ROOT"
exec ./build-tools/build.sh \
  --build "$BUILD_DIR" \
  --c-compiler /usr/bin/clang-18 \
  --cxx-compiler /usr/bin/clang++-18 \
  --add-cmake-options "-DCMAKE_LINKER=/usr/bin/mold -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=mold -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=mold -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=mold" \
  --build-bishengir-template \
  --bisheng-compiler "$CANN_PATH/bin" \
  "$@"

#!/usr/bin/env bash

set -euo pipefail

IR_ROOT="${IR_ROOT:-/workspace/AscendNPU-IR}"
TRITON_ROOT="${TRITON_ROOT:-/workspace/triton-ascend}"
BUILD_DIR="${BUILD_DIR:-build-ubuntu20}"

[[ -d "$TRITON_ROOT" ]] || {
  printf 'Triton-Ascend checkout not found: %s\n' "$TRITON_ROOT" >&2
  exit 1
}
[[ -d "$IR_ROOT/$BUILD_DIR/install" ]] || {
  printf 'AscendNPU-IR install not found: %s\n' "$IR_ROOT/$BUILD_DIR/install" >&2
  exit 1
}

cd "$TRITON_ROOT"
source /usr/local/Ascend/cann/set_env.sh
export LLVM_SYSPATH="/workspace/AscendNPU-IR/$BUILD_DIR/install"
export TRITON_BUILD_WITH_CCACHE="${TRITON_BUILD_WITH_CCACHE:-true}"
export TRITON_BUILD_WITH_CLANG_LLD="false"
export TRITON_BUILD_PROTON="OFF"
export TRITON_WHEEL_NAME="triton-ascend"
export TRITON_APPEND_CMAKE_ARGS="${TRITON_APPEND_CMAKE_ARGS:--DTRITON_BUILD_UT=OFF}"

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'detached')"
branch="${branch//\//-}"
branch="${branch//[^A-Za-z0-9_.-]/-}"
commit="$(git rev-parse --short=12 HEAD)"
export TRITON_WHEEL_VERSION_SUFFIX="${TRITON_WHEEL_VERSION_SUFFIX:-.post0+${branch}.${commit}}"

rm -f "$TRITON_ROOT"/triton_ascend-*.whl
python3.10 setup_ascend.py bdist_wheel --dist-dir "$TRITON_ROOT" "$@"
find "$TRITON_ROOT" -maxdepth 1 -type f -name 'triton_ascend-*.whl' \
  -printf 'Created %p\n'

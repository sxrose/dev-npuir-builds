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
set +u
source "${ASCEND_HOME_PATH:-/opt/Ascend/cann}/set_env.sh"
set -u

# The Triton extension builds against upstream LLVM 22 (f6ded0b8 +
# llvm_patch_f6ded0b.patch); setup downloads the matching prebuilt when
# LLVM_SYSPATH is unset. The AscendNPU-IR install is the LLVM 19.1.7 fork used
# only to build bishengir-compile and is incompatible with Triton.
unset LLVM_SYSPATH

# Ubuntu 20.04 has glibc 2.31, but the ubuntu-x64 prebuilt needs glibc 2.32+.
# The almalinux-x64 build targets glibc 2.28 and runs here (verified: mlir-tblgen
# needs at most GLIBC_2.16 / GLIBCXX_3.4.21).
export TRITON_LLVM_SYSTEM_SUFFIX="${TRITON_LLVM_SYSTEM_SUFFIX:-almalinux-x64}"

# manylinux: auditwheel is installed in the image and IS_MANYLINUX keeps the
# `.post0+branch.commit` suffix a single valid PEP 440 local segment.
export IS_MANYLINUX="${IS_MANYLINUX:-1}"

export TRITON_BUILD_WITH_CCACHE="${TRITON_BUILD_WITH_CCACHE:-true}"
export TRITON_BUILD_WITH_CLANG_LLD="false"
export TRITON_BUILD_PROTON="OFF"
export TRITON_WHEEL_NAME="triton-ascend"
export TRITON_APPEND_CMAKE_ARGS="${TRITON_APPEND_CMAKE_ARGS:--DTRITON_BUILD_UT=OFF -DCMAKE_LINKER=/usr/bin/mold -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=mold -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=mold -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=mold}"

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'detached')"
branch="${branch//\//-}"
branch="${branch//[^A-Za-z0-9_.-]/-}"
commit="$(git rev-parse --short=12 HEAD)"
export TRITON_WHEEL_VERSION_SUFFIX="${TRITON_WHEEL_VERSION_SUFFIX:-.post0+${branch}.${commit}}"

rm -f "$TRITON_ROOT"/triton_ascend-*.whl
"${PYTHON:-python3.11}" setup_ascend.py bdist_wheel --dist-dir "$TRITON_ROOT" "$@"
find "$TRITON_ROOT" -maxdepth 1 -type f -name 'triton_ascend-*.whl' \
  -printf 'Created %p\n'

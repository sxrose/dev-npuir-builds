#!/usr/bin/env bash

set -euo pipefail

TRITON_ROOT="${TRITON_ROOT:-/workspace/triton-ascend}"
LLVM_INSTALL="${LLVM_INSTALL:-/workspace/llvm-install}"

[[ -d "$TRITON_ROOT" ]] || {
  printf 'Triton-Ascend checkout not found: %s\n' "$TRITON_ROOT" >&2
  exit 1
}
[[ -f "$LLVM_INSTALL/bin/mlir-tblgen" ]] || {
  printf 'LLVM install not found: %s/bin/mlir-tblgen\n' "$LLVM_INSTALL" >&2
  printf 'Run build-llvm first (./run.sh build-llvm.sh).\n' >&2
  exit 1
}

cd "$TRITON_ROOT"
set +u
source "${ASCEND_HOME_PATH:-/opt/Ascend/cann}/set_env.sh"
set -u

# Build against the locally built upstream LLVM 22 (f6ded0b8 + llvm_patch).
# Neither prebuilt works on Ubuntu 20.04: ubuntu-x64 needs glibc 2.32+, and
# almalinux-x64 needs a newer libstdc++ (__glibcxx_assert_fail). The
# AscendNPU-IR install is the LLVM 19.1.7 fork used only by bishengir-compile.
export LLVM_SYSPATH="$LLVM_INSTALL"

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

#!/usr/bin/env bash

set -euo pipefail

TRITON_ROOT="${TRITON_ROOT:-/workspace/triton-ascend}"
LLVM_INSTALL="${LLVM_INSTALL:-/workspace/llvm-install}"

[[ -d "$TRITON_ROOT" ]] || {
  printf 'Triton-Ascend checkout not found: %s\n' "$TRITON_ROOT" >&2
  exit 1
}
# The installed LLVM must match the commit pinned by this Triton checkout. If
# it does not, sync the source to that commit and build it automatically.
LLVM_REV="$(tr -d '[:space:]' < "$TRITON_ROOT/cmake/llvm-hash.txt")"
LLVM_STAMP="$LLVM_INSTALL/.llvm-rev"
if [[ ! -f "$LLVM_INSTALL/bin/mlir-tblgen" || ! -f "$LLVM_STAMP" || \
      "$(cat "$LLVM_STAMP")" != "$LLVM_REV" ]]; then
  command -v build-llvm.sh >/dev/null 2>&1 || {
    printf 'build-llvm.sh not found; run ./run.sh build-llvm.sh first\n' >&2
    exit 1
  }
  printf 'LLVM at %s does not match cmake/llvm-hash.txt (%s), building it ...\n' \
    "$LLVM_INSTALL" "$LLVM_REV"
  build-llvm.sh
fi

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

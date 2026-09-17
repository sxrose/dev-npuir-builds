#!/usr/bin/env bash

set -euo pipefail

TRITON_ROOT="${TRITON_ROOT:-/workspace/triton-ascend}"
LLVM_INSTALL="${LLVM_INSTALL:-/workspace/llvm-install}"

[[ -d "$TRITON_ROOT" ]] || {
  printf 'Triton-Ascend checkout not found: %s\n' "$TRITON_ROOT" >&2
  exit 1
}
# Sync the LLVM install with the commit/options pinned by this Triton checkout
# (build-llvm.sh checks the stamp and is a no-op when it already matches).
command -v build-llvm.sh >/dev/null 2>&1 || {
  printf 'build-llvm.sh not found; run ./run.sh build-llvm.sh first\n' >&2
  exit 1
}
build-llvm.sh --skip-if-fresh

cd "$TRITON_ROOT"
set +u
source "${ASCEND_HOME_PATH:-/opt/Ascend/cann}/set_env.sh"
set -u

# Build against the locally built upstream LLVM 22 (f6ded0b8 + llvm_patch).
# Neither prebuilt works on Ubuntu 20.04: ubuntu-x64 needs glibc 2.32+, and
# almalinux-x64 needs a newer libstdc++ (__glibcxx_assert_fail). The
# AscendNPU-IR install is the LLVM 19.1.7 fork used only by bishengir-compile.
export LLVM_SYSPATH="$LLVM_INSTALL"

# A CMake build directory configured against a different LLVM keeps stale
# absolute paths to that LLVM's static libs in its cache. Wipe it whenever the
# LLVM location changes (or is unknown) so nothing links against the old one.
LLVM_PATH_STAMP="$TRITON_ROOT/build/.llvm-syspath"
if [[ ! -f "$LLVM_PATH_STAMP" || "$(cat "$LLVM_PATH_STAMP")" != "$LLVM_SYSPATH" ]]; then
  printf 'LLVM path changed, cleaning %s\n' "$TRITON_ROOT/build"
  rm -rf "$TRITON_ROOT/build"
fi
mkdir -p "$TRITON_ROOT/build"
printf '%s\n' "$LLVM_SYSPATH" > "$LLVM_PATH_STAMP"

export TRITON_BUILD_WITH_CCACHE="${TRITON_BUILD_WITH_CCACHE:-true}"
export TRITON_BUILD_WITH_CLANG_LLD="false"
export TRITON_BUILD_PROTON="OFF"
export TRITON_WHEEL_NAME="triton-ascend"
export TRITON_APPEND_CMAKE_ARGS="${TRITON_APPEND_CMAKE_ARGS:--DTRITON_BUILD_UT=OFF -DCMAKE_LINKER=/usr/bin/mold -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=mold -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=mold -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=mold}"

# The wheel is NOT manylinux: Ubuntu 20.04 (glibc 2.31, GCC 9 libstdc++) cannot
# be repaired to manylinux_2_28. Without IS_MANYLINUX setup appends the git hash
# as the local version segment, so the suffix must not contain a second "+"
# (PEP 440 allows only one). Result: 3.6.0.post0+git<short-hash>.
export TRITON_WHEEL_VERSION_SUFFIX="${TRITON_WHEEL_VERSION_SUFFIX:-.post0}"

rm -f "$TRITON_ROOT"/triton_ascend-*.whl
"${PYTHON:-python3.11}" setup_ascend.py bdist_wheel --dist-dir "$TRITON_ROOT" "$@"
find "$TRITON_ROOT" -maxdepth 1 -type f -name 'triton_ascend-*.whl' \
  -printf 'Created %p\n'

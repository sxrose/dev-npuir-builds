#!/usr/bin/env bash

set -euo pipefail

TRITON_ROOT="${TRITON_ROOT:-/workspace/triton-ascend}"
LLVM_SRC="${LLVM_SRC:-/workspace/llvm-project}"
LLVM_INSTALL="${LLVM_INSTALL:-/workspace/llvm-install}"
LLVM_REV="${LLVM_REV:-f6ded0be897e2878612dd903f7e8bb85448269e5}"
LLVM_PATCH="$TRITON_ROOT/third_party/ascend/patch/llvm_patch_f6ded0b.patch"
BUILD_DIR="$LLVM_SRC/build"

[[ -d "$TRITON_ROOT" ]] || {
  printf 'Triton-Ascend checkout not found: %s\n' "$TRITON_ROOT" >&2
  exit 1
}
[[ -f "$LLVM_PATCH" ]] || {
  printf 'LLVM patch not found: %s\n' "$LLVM_PATCH" >&2
  exit 1
}

if [[ -f "$LLVM_INSTALL/bin/mlir-tblgen" && "${1:-}" != "--force" ]]; then
  printf 'LLVM already installed at %s (use --force to rebuild)\n' "$LLVM_INSTALL"
  exit 0
fi

mkdir -p "$LLVM_SRC"
if [[ ! -d "$LLVM_SRC/.git" ]]; then
  git init "$LLVM_SRC"
  git -C "$LLVM_SRC" remote add origin https://github.com/llvm/llvm-project.git
fi

git -C "$LLVM_SRC" fetch --depth 1 origin "$LLVM_REV"
git -C "$LLVM_SRC" checkout -f FETCH_HEAD
git -C "$LLVM_SRC" apply "$LLVM_PATCH"

cmake -G Ninja -S "$LLVM_SRC/llvm" -B "$BUILD_DIR" \
  -DCMAKE_C_COMPILER=/usr/bin/clang-18 \
  -DCMAKE_CXX_COMPILER=/usr/bin/clang++-18 \
  -DCMAKE_LINKER=/usr/bin/mold \
  -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=mold \
  -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=mold \
  -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=mold \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="mlir;llvm;lld" \
  -DLLVM_TARGETS_TO_BUILD="host;NVPTX;AMDGPU" \
  -DLLVM_INSTALL_UTILS=ON \
  -DCMAKE_INSTALL_PREFIX="$LLVM_INSTALL"

ninja -C "$BUILD_DIR" install

printf 'Installed LLVM %s to %s\n' "$LLVM_REV" "$LLVM_INSTALL"

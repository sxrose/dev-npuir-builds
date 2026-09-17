#!/usr/bin/env bash

set -euo pipefail

TRITON_ROOT="${TRITON_ROOT:-/workspace/triton-ascend}"
LLVM_SRC="${LLVM_SRC:-/workspace/llvm-project}"
LLVM_INSTALL="${LLVM_INSTALL:-/workspace/llvm-install}"
PATCH_DIR="$TRITON_ROOT/third_party/ascend/patch"
BUILD_DIR="$LLVM_SRC/build"
LLVM_URL="${LLVM_URL:-https://github.com/llvm/llvm-project.git}"

SKIP_IF_FRESH=0
for arg in "$@"; do
  case "$arg" in
    --skip-if-fresh) SKIP_IF_FRESH=1 ;;
    *)
      printf 'Unknown option: %s (supported: --skip-if-fresh)\n' "$arg" >&2
      exit 2
      ;;
  esac
done

[[ -d "$TRITON_ROOT" ]] || {
  printf 'Triton-Ascend checkout not found: %s\n' "$TRITON_ROOT" >&2
  exit 1
}

# Keep the LLVM revision in sync with the Triton checkout instead of pinning it.
HASH_FILE="$TRITON_ROOT/cmake/llvm-hash.txt"
[[ -f "$HASH_FILE" ]] || {
  printf 'LLVM hash file not found: %s\n' "$HASH_FILE" >&2
  exit 1
}
LLVM_REV="${LLVM_REV:-$(tr -d '[:space:]' < "$HASH_FILE")}"
[[ -n "$LLVM_REV" ]] || {
  printf 'Empty LLVM revision in %s\n' "$HASH_FILE" >&2
  exit 1
}

# Patch file name is derived from the revision's short prefix (e.g. f6ded0b);
# fall back to the only llvm_patch_*.patch when the naming does not match.
LLVM_PATCH="${LLVM_PATCH:-}"
if [[ -z "$LLVM_PATCH" ]]; then
  LLVM_PATCH="$PATCH_DIR/llvm_patch_${LLVM_REV:0:7}.patch"
  if [[ ! -f "$LLVM_PATCH" ]]; then
    LLVM_PATCH="$(find "$PATCH_DIR" -maxdepth 1 -name 'llvm_patch_*.patch' | sort | head -n1)"
  fi
fi
[[ -f "$LLVM_PATCH" ]] || {
  printf 'LLVM patch not found: %s\n' "$LLVM_PATCH" >&2
  exit 1
}

# ZLIB/ZSTD are disabled: lld's exported config references the ZLIB::ZLIB
# imported target, but Triton only does find_package(LLD) without
# find_package(ZLIB), so the target must not be required.
CMAKE_ARGS=(
  "-DCMAKE_C_COMPILER=/usr/bin/clang-18"
  "-DCMAKE_CXX_COMPILER=/usr/bin/clang++-18"
  "-DCMAKE_LINKER=/usr/bin/mold"
  "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=mold"
  "-DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=mold"
  "-DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=mold"
  "-DCMAKE_BUILD_TYPE=Release"
  "-DLLVM_ENABLE_ASSERTIONS=ON"
  "-DLLVM_ENABLE_PROJECTS=mlir;llvm;lld"
  "-DLLVM_TARGETS_TO_BUILD=host;NVPTX;AMDGPU"
  "-DLLVM_INSTALL_UTILS=ON"
  "-DLLVM_ENABLE_ZLIB=OFF"
  "-DLLVM_ENABLE_ZSTD=OFF"
  "-DCMAKE_INSTALL_PREFIX=$LLVM_INSTALL"
)

# The stamp covers both the revision and the build options, so changing either
# forces a rebuild.
CONFIG_SIG="$(printf '%s\n' "${CMAKE_ARGS[@]}" | sha256sum | cut -c1-12)"
STAMP="$LLVM_INSTALL/.llvm-rev"
STAMP_VALUE="$LLVM_REV $CONFIG_SIG"

# By default always sync and build; --skip-if-fresh makes the step a no-op when
# the installed LLVM already matches the requested revision and options.
if [[ "$SKIP_IF_FRESH" -eq 1 && -f "$STAMP" && -f "$LLVM_INSTALL/bin/mlir-tblgen" && \
      "$(cat "$STAMP")" == "$STAMP_VALUE" ]]; then
  printf 'LLVM %s already installed at %s, skipping\n' "$LLVM_REV" "$LLVM_INSTALL"
  exit 0
fi

printf 'LLVM source: %s\nLLVM rev:    %s\nLLVM patch:  %s\n' "$LLVM_SRC" "$LLVM_REV" "$(basename "$LLVM_PATCH")"

# No checkout yet: clone and check out the requested revision.
if [[ ! -d "$LLVM_SRC/.git" ]]; then
  printf 'Cloning %s ...\n' "$LLVM_URL"
  git init "$LLVM_SRC"
  git -C "$LLVM_SRC" remote add origin "$LLVM_URL"
  git -C "$LLVM_SRC" fetch --depth 1 origin "$LLVM_REV"
  git -C "$LLVM_SRC" checkout -f FETCH_HEAD
else
  # Existing checkout: verify the revision and update only when it differs.
  current="$(git -C "$LLVM_SRC" rev-parse HEAD 2>/dev/null || true)"
  if [[ "$current" != "$LLVM_REV" ]]; then
    printf 'Updating LLVM %s -> %s ...\n' "${current:0:12}" "${LLVM_REV:0:12}"
    git -C "$LLVM_SRC" remote set-url origin "$LLVM_URL"
    git -C "$LLVM_SRC" fetch --depth 1 origin "$LLVM_REV"
    git -C "$LLVM_SRC" checkout -f FETCH_HEAD
  else
    printf 'LLVM source already at %s\n' "$LLVM_REV"
  fi
fi

# Apply the patch unless it is already present in the working tree.
if git -C "$LLVM_SRC" apply --reverse --check "$LLVM_PATCH" >/dev/null 2>&1; then
  printf 'Patch already applied\n'
else
  git -C "$LLVM_SRC" apply "$LLVM_PATCH"
fi

cmake -G Ninja -S "$LLVM_SRC/llvm" -B "$BUILD_DIR" "${CMAKE_ARGS[@]}"

ninja -C "$BUILD_DIR" install

printf '%s\n' "$STAMP_VALUE" > "$STAMP"
printf 'Installed LLVM %s to %s\n' "$LLVM_REV" "$LLVM_INSTALL"

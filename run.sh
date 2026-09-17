#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${IMAGE:-ascendnpu-ir-ubuntu20-builder}"

IR_ROOT="${IR_ROOT:-$REPO_DIR/../AscendNPU-IR}"
TRITON_ROOT="${TRITON_ROOT:-$REPO_DIR/../triton-ascend}"
LLVM_SRC="${LLVM_SRC:-$REPO_DIR/../llvm-project}"
LLVM_INSTALL="${LLVM_INSTALL:-$REPO_DIR/../llvm-install}"
CANN_HOME="${CANN_HOME-$REPO_DIR/../cann}"
CACHE_HOME="${CACHE_HOME-$HOME/.cache/dev-npuir-builds}"

IR_ROOT="$(realpath "$IR_ROOT")"
TRITON_ROOT="$(realpath "$TRITON_ROOT")"
CANN_HOME="$(realpath -m "$CANN_HOME")"
LLVM_SRC="$(realpath -m "$LLVM_SRC")"
LLVM_INSTALL="$(realpath -m "$LLVM_INSTALL")"
mkdir -p "$LLVM_SRC" "$LLVM_INSTALL"

[[ -d "$IR_ROOT" ]] || {
  printf 'AscendNPU-IR checkout not found: %s\n' "$IR_ROOT" >&2
  printf 'Set IR_ROOT to its location.\n' >&2
  exit 1
}
[[ -d "$TRITON_ROOT" ]] || {
  printf 'Triton-Ascend checkout not found: %s\n' "$TRITON_ROOT" >&2
  printf 'Set TRITON_ROOT to its location.\n' >&2
  exit 1
}

if [[ ! -f "$CANN_HOME/set_env.sh" ]]; then
  CANN_HOME="$CANN_HOME" IMAGE="$IMAGE" "$REPO_DIR/setup-cann.sh"
fi

# CANN's set_env.sh hardcodes its install path, so the host directory has to be
# mounted at the very same path inside the container. Read that path back from
# set_env.sh; fall back to the path a fresh setup-cann.sh install uses.
CANN_CONTAINER_PATH="${CANN_CONTAINER_PATH:-}"
if [[ -z "$CANN_CONTAINER_PATH" ]]; then
  CANN_CONTAINER_PATH="$(
    grep -o 'version_dirpath="[^"]*"' "$CANN_HOME/set_env.sh" \
      | head -n1 | cut -d'"' -f2
  )"
  CANN_CONTAINER_PATH="${CANN_CONTAINER_PATH:-/opt/Ascend/cann}"
fi

docker_args=(
  --rm
  --user "$(id -u):$(id -g)"
  --env ASCEND_HOME_PATH="$CANN_CONTAINER_PATH"
  --env BISHENG_COMPILER="$CANN_CONTAINER_PATH/bin"
  --env LD_LIBRARY_PATH="$CANN_CONTAINER_PATH/lib64"
  --env IR_ROOT=/workspace/AscendNPU-IR
  --env TRITON_ROOT=/workspace/triton-ascend
  --env LLVM_SRC=/workspace/llvm-project
  --env LLVM_INSTALL=/workspace/llvm-install
  --volume "$CANN_HOME:$CANN_CONTAINER_PATH"
  --volume "$IR_ROOT:/workspace/AscendNPU-IR"
  --volume "$TRITON_ROOT:/workspace/triton-ascend"
  --volume "$LLVM_SRC:/workspace/llvm-project"
  --volume "$LLVM_INSTALL:/workspace/llvm-install"
  # Mount the scripts over the baked copies so edits take effect without
  # rebuilding the image.
  --volume "$REPO_DIR/scripts/build-compiler.sh:/usr/local/bin/build-compiler.sh:ro"
  --volume "$REPO_DIR/scripts/build-llvm.sh:/usr/local/bin/build-llvm.sh:ro"
  --volume "$REPO_DIR/scripts/build-wheel.sh:/usr/local/bin/build-wheel.sh:ro"
  --volume "$REPO_DIR/scripts/pack-compiler.sh:/usr/local/bin/pack-compiler.sh:ro"
  --workdir /workspace/AscendNPU-IR
)

if [[ -n "$CACHE_HOME" ]]; then
  # Persist the container home (and ccache at ~/.ccache) on the host, so it
  # survives --rm and is private to the host user.
  mkdir -p "$CACHE_HOME/home"
  docker_args+=(
    --env HOME=/home/user
    --env CCACHE_DIR=/home/user/.ccache
    --volume "$CACHE_HOME/home:/home/user"
  )
else
  docker_args+=(--env HOME=/tmp)
fi

if (( $# )); then
  exec docker run "${docker_args[@]}" \
    --entrypoint /bin/bash \
    "$IMAGE" -c "$*"
fi

exec docker run -it "${docker_args[@]}" "$IMAGE"

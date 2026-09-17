#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${IMAGE:-ascendnpu-ir-ubuntu20-builder}"

IR_ROOT="${IR_ROOT:-$REPO_DIR/../AscendNPU-IR}"
TRITON_ROOT="${TRITON_ROOT:-$REPO_DIR/../triton-ascend}"
CACHE_HOME="${CACHE_HOME-$HOME/.cache/dev-npuir-builds}"

IR_ROOT="$(realpath "$IR_ROOT")"
TRITON_ROOT="$(realpath "$TRITON_ROOT")"

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

docker_args=(
  --rm
  --user "$(id -u):$(id -g)"
  --env ASCEND_HOME_PATH=/usr/local/Ascend/cann
  --env IR_ROOT=/workspace/AscendNPU-IR
  --env TRITON_ROOT=/workspace/triton-ascend
  --volume "$IR_ROOT:/workspace/AscendNPU-IR"
  --volume "$TRITON_ROOT:/workspace/triton-ascend"
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

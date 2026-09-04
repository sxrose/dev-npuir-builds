#!/usr/bin/env bash

set -euo pipefail

IMAGE="${IMAGE:-ascendnpu-ir-ubuntu20-builder}"
TRITON_DIR="${TRITON_DIR:-$PWD/../triton-ascend}"
WHEEL_DIR="${WHEEL_DIR:-$TRITON_DIR/dist}"
IR_BUILD_DIR="${IR_BUILD_DIR:-$PWD/build-ubuntu20}"

if [[ ! -d "$TRITON_DIR" ]]; then
  printf 'Triton-Ascend checkout not found: %s\n' "$TRITON_DIR" >&2
  exit 1
fi

if [[ ! -d "$IR_BUILD_DIR/install" ]]; then
  printf 'AscendNPU-IR install not found: %s\n' "$IR_BUILD_DIR/install" >&2
  printf 'Build AscendNPU-IR first with docker/build-ubuntu20.sh.\n' >&2
  exit 1
fi

mkdir -p "$WHEEL_DIR"

docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  --env HOME=/tmp \
  --env ASCEND_HOME_PATH=/usr/local/Ascend/cann \
  --env IR_ROOT=/workspace/AscendNPU-IR \
  --env TRITON_ROOT=/workspace/triton-ascend \
  --env BUILD_DIR="$(basename "$IR_BUILD_DIR")" \
  --env TRITON_BUILD_WITH_CCACHE=true \
  --env TRITON_BUILD_WITH_CLANG_LLD=false \
  --env TRITON_BUILD_PROTON=OFF \
  --env TRITON_WHEEL_NAME=triton-ascend \
  --env TRITON_APPEND_CMAKE_ARGS="-DTRITON_BUILD_UT=OFF -DCMAKE_LINKER=/usr/bin/mold -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=mold -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=mold -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=mold" \
  --volume "$PWD:/workspace/AscendNPU-IR" \
  --volume "$TRITON_DIR:/workspace/triton-ascend" \
  --volume "$WHEEL_DIR:/workspace/triton-ascend/dist" \
  --workdir /workspace/triton-ascend \
  "$IMAGE" \
  build-wheel.sh

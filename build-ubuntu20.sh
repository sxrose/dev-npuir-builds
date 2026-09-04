#!/usr/bin/env bash

set -euo pipefail

IMAGE="${IMAGE:-ascendnpu-ir-ubuntu20-builder}"
BUILD_DIR="${BUILD_DIR:-build-ubuntu20}"
CANN_PATH="${CANN_PATH:-/usr/local/Ascend/cann}"

mkdir -p "$PWD/$BUILD_DIR"

docker build \
  --file docker/Dockerfile.ubuntu20 \
  --tag "$IMAGE" \
  .

docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  --env HOME=/tmp \
  --volume "$PWD:/workspace/AscendNPU-IR" \
  --workdir /workspace/AscendNPU-IR \
  "$IMAGE" \
  ./build-tools/build.sh \
    --build "$BUILD_DIR" \
    --c-compiler /usr/bin/clang-18 \
    --cxx-compiler /usr/bin/clang++-18 \
    --add-cmake-options "-DCMAKE_LINKER=/usr/bin/mold -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=mold -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=mold -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=mold" \
    --build-bishengir-template \
    --bisheng-compiler "$CANN_PATH/bin" \
    "$@"

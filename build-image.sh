#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${IMAGE:-ascendnpu-ir-ubuntu20-builder}"

docker build "$@" \
  --file "$REPO_DIR/Dockerfile" \
  --tag "$IMAGE" \
  "$REPO_DIR"

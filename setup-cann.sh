#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${IMAGE:-ascendnpu-ir-ubuntu20-builder}"

CANN_HOME="${CANN_HOME-$REPO_DIR/../cann}"
CANN_URL="${CANN_URL:-https://ascend-cann-open.obs.cn-north-4.myhuaweicloud.com/CANN/CANN%209.2.0-beta.2/Ascend-cann_9.2.0-beta.2_linux-x86_64.run}"
CANN_SHA256="${CANN_SHA256:-}"

CANN_HOME="$(realpath -m "$CANN_HOME")"
PKG_NAME="$(basename "$CANN_URL")"
PKG_DIR="${CANN_PKG_DIR:-$(dirname "$CANN_HOME")/.cann-pkg}"
PKG_FILE="$PKG_DIR/$PKG_NAME"

if [[ -f "$CANN_HOME/set_env.sh" ]]; then
  printf 'CANN already installed: %s\n' "$CANN_HOME"
  exit 0
fi

docker image inspect "$IMAGE" >/dev/null 2>&1 || {
  printf 'Image not found: %s\n' "$IMAGE" >&2
  printf 'Build it first with ./build-image.sh.\n' >&2
  exit 1
}

mkdir -p "$CANN_HOME" "$PKG_DIR"

if [[ ! -f "$PKG_FILE" ]]; then
  printf 'Downloading %s\n' "$CANN_URL"
  curl -fL --retry 3 -C - --output "$PKG_FILE" "$CANN_URL"
fi

if [[ -n "$CANN_SHA256" ]]; then
  printf '%s  %s\n' "$CANN_SHA256" "$PKG_FILE" | sha256sum -c -
fi

# Install as the host user (non-root) inside the container: this installs the
# toolkit only and never touches the driver/firmware.
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --env HOME=/tmp \
  --volume "$CANN_HOME:/opt/Ascend/cann" \
  --volume "$PKG_FILE:/tmp/cann.run:ro" \
  --entrypoint /bin/bash \
  "$IMAGE" \
  -c 'bash /tmp/cann.run --install --whitelist=toolkit --install-path=/opt/Ascend --quiet'

[[ -f "$CANN_HOME/set_env.sh" ]] || {
  printf 'Installation finished but %s/set_env.sh is missing.\n' "$CANN_HOME" >&2
  exit 1
}

printf 'CANN installed: %s\n' "$CANN_HOME"

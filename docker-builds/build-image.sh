#!/usr/bin/env bash

set -eou pipefail

BUILD_IMAGE=ascend-builder

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --build-image         specify docker image name [default: $BUILD_IMAGE]"
    echo "  -h, --help            display this help message"
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage 0
            ;;
        --build-image)
            if [[ -z "${2:-}" ]]; then
                echo "Error: Option $1 requires an argument." >&2
                usage 1
            fi
            BUILD_IMAGE="$2"
            shift 2
            ;;
        -*|--*)
            echo "Unknown option: $1" >&2
            usage 1
            ;;
    esac
done

DIR=$(dirname ${BASH_SOURCE[0]} | xargs realpath)
cd $DIR/base

docker build -t $BUILD_IMAGE .


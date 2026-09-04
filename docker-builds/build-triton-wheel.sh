#!/usr/bin/env bash

set -eou pipefail

BRANCH=main
REPO_URL=http://github.com/triton-lang/triton-ascend.git

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --branch-name BRANCH  specify branch name in triton-ascend repo [default: $BRANCH]"
    echo "  --url                 specify triton-ascend repo URL [default: $REPO_URL]"
    echo "  -h, --help            display this help message"
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage 0
            ;;
        --branch-name)
            if [[ -z "${2:-}" ]]; then
                echo "Error: Option $1 requires an argument." >&2
                usage 1
            fi
            BRANCH="$2"
            shift 2
            ;;
        --url)
            if [[ -z "${2:-}" ]]; then
                echo "Error: Option $1 requires an argument." >&2
                usage 1
            fi
            REPO_URL="$2"
            shift 2
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
cd $DIR/triton-ascend

docker build --no-cache --output=. --build-arg TRITON_BRANCH=$BRANCH \
                                   --build-arg TRITON_REPO_URL=$REPO_URL .


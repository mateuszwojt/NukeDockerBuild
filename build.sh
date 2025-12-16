#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <nuke-version> <windows/linux> [optional: --podman, --skip-load]"
    exit 1
fi

NUKEVERSION="$1"
OPERATING_SYSTEM="$2"
USE_PODMAN=false
SKIP_LOAD=false

for arg in "${@:3}"; do
    case "$arg" in
        --podman) USE_PODMAN=true ;;
        --skip-load) SKIP_LOAD=true ;;
    esac
done

# Use proper Windows path format
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W)"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if $USE_PODMAN; then
    command -v podman &> /dev/null || { echo "Podman not installed. Please install that first."; exit 1; }
else
    command -v docker &> /dev/null || { echo "Docker not installed. Please install that first."; exit 1; }
fi

echo "Starting build for: '${NUKEVERSION}'."
mkdir -p build

if $USE_PODMAN; then
    podman run \
        -v "${SCRIPT_DIR}:/nukedockerbuild" \
        -v "${SCRIPT_DIR}/build:/build" \
        --rm \
        --cap-add=sys_admin,mknod \
        --device=/dev/fuse \
        --security-opt label=disable \
        quay.io/podman/stable:latest \
        bash -c "/nukedockerbuild/scripts/build.sh ${NUKEVERSION} ${OPERATING_SYSTEM} --podman"

    if ! $SKIP_LOAD; then
        docker load -i "${SCRIPT_DIR}/build/nukedockerbuild-${NUKEVERSION}-${OPERATING_SYSTEM}.tar.gz"
        
        docker run \
            -v "${SCRIPT_DIR}/build:/build" \
            --rm \
            docker.io/docker:dind \
            sh -c "rm -rf /build/nukedockerbuild-${NUKEVERSION}-${OPERATING_SYSTEM}.tar.gz"
    fi

else
    # Ensure no leftover container exists from a crash
    docker rm -f nuke_builder_active 2>/dev/null || true

    docker run \
        --name nuke_builder_active \
        -v "${SCRIPT_DIR}:/nukedockerbuild" \
        -v "${SCRIPT_DIR}/build:/build" \
        -v //var/run/docker.sock:/var/run/docker.sock \
        --rm \
        --network host \
        docker.io/docker:dind \
        sh -c "apk add --no-cache bash curl ca-certificates && \
        /nukedockerbuild/scripts/build.sh ${NUKEVERSION} ${OPERATING_SYSTEM}"

    if ! $SKIP_LOAD; then
        # Ensure filenames use dashes, not colons
        docker load -i "${SCRIPT_DIR}/build/nukedockerbuild-${NUKEVERSION}-${OPERATING_SYSTEM}.tar.gz"
        
        docker run \
            -v "${SCRIPT_DIR}/build:/build" \
            --rm \
            docker.io/docker:dind \
            sh -c "rm -rf /build/nukedockerbuild-${NUKEVERSION}-${OPERATING_SYSTEM}.tar.gz"
    fi
fi
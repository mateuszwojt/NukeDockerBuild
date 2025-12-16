#!/bin/bash
set -e # Exit immediately on error

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if $USE_PODMAN; then
    command -v podman &> /dev/null || { echo "Podman not installed. Please install that first."; exit 1; }
else
    command -v docker &> /dev/null || { echo "Docker not installed. Please install that first."; exit 1; }
fi

echo "Starting build for: '${NUKEVERSION}'."
mkdir -p build

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Convert /c/Users/... to C:/Users/... (Mixed mode: Windows drive + Forward slashes)
    # This prevents backslash escaping issues in Git Bash
    HOST_PATH=$(cygpath -m "$SCRIPT_DIR")
    # Prevent Git Bash from mangling the socket path by using double slash
    SOCK_PATH="//var/run/docker.sock"
else
    # Linux / Mac
    HOST_PATH="$SCRIPT_DIR"
    SOCK_PATH="/var/run/docker.sock"
fi

if $USE_PODMAN; then
    podman run \
        -v "${HOST_PATH}:/nukedockerbuild" \
        -v "${HOST_PATH}/build:/build" \
        --rm \
        --cap-add=sys_admin,mknod \
        --device=/dev/fuse \
        --security-opt label=disable \
        quay.io/podman/stable:latest \
        bash -c "dnf install -y dos2unix findutils && \
                 find /nukedockerbuild/scripts -name '*.sh' -exec dos2unix {} \; && \
                 bash /nukedockerbuild/scripts/build.sh ${NUKEVERSION} ${OPERATING_SYSTEM} --podman"

    if ! $SKIP_LOAD; then
        # Use relative path for load to avoid Git Bash confusion
        cd "${SCRIPT_DIR}/build"
        if [ -f "nukedockerbuild-${NUKEVERSION}-${OPERATING_SYSTEM}.tar.gz" ]; then
            podman load -i "nukedockerbuild-${NUKEVERSION}-${OPERATING_SYSTEM}.tar.gz"
            rm -f "nukedockerbuild-${NUKEVERSION}-${OPERATING_SYSTEM}.tar.gz"
        fi
    fi

else
    # DOCKER EXECUTION
    docker run \
        -v "${HOST_PATH}:/nukedockerbuild" \
        -v "${HOST_PATH}/build:/build" \
        -v ${SOCK_PATH}:/var/run/docker.sock \
        --rm \
        docker.io/docker:dind \
        sh -c "apk add --no-cache bash dos2unix findutils && \
        find /nukedockerbuild/scripts -name '*.sh' -exec dos2unix {} \; && \
        bash /nukedockerbuild/scripts/build.sh ${NUKEVERSION} ${OPERATING_SYSTEM}"

    if ! $SKIP_LOAD; then
        echo "Loading image into Docker..."
        cd "${SCRIPT_DIR}/build" || exit 1
        TAR_FILE="nukedockerbuild-${NUKEVERSION}-${OPERATING_SYSTEM}.tar.gz"
        
        if [ -f "$TAR_FILE" ]; then
            docker load -i "$TAR_FILE"
            rm -f "$TAR_FILE"
        else
            echo "Error: $TAR_FILE not found. The build inside the container likely failed."
            exit 1
        fi
    fi
fi
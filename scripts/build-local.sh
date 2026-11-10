#!/usr/bin/env bash
#
# Helper script to test the build locally using Docker
#
set -euo pipefail

OPENWRT_VER="${OPENWRT_VER:-24.10.0}"
TARGET="${TARGET:-mediatek}"
SUBTARGET="${SUBTARGET:-filogic}"

echo "=================================================="
echo "Local build test using Docker"
echo "Target: ${TARGET}/${SUBTARGET} (${OPENWRT_VER})"
echo "=================================================="

# Check docker
if ! command -v docker > /dev/null 2>&1; then
    echo "Error: docker is required to run a local build test."
    exit 1
fi

docker run --rm -it \
    -v "$(pwd):/workspace" \
    -w /workspace \
    ubuntu:24.04 bash -c '
        set -euo pipefail
        apt-get update && apt-get install -y \
            build-essential clang flex bison gawk gettext gcc-multilib g++-multilib \
            libncurses5-dev zlib1g-dev libssl-dev libelf-dev zstd git rsync file \
            wget curl python3 cmake xz-utils pkg-config

        echo "==> Downloading OpenWrt SDK..."
        SDK_TAR="openwrt-sdk-24.10.0-mediatek-filogic_gcc-13.3.0_musl.Linux-x86_64.tar.zst"
        SDK_URL="https://downloads.openwrt.org/releases/24.10.0/targets/mediatek/filogic/${SDK_TAR}"
        
        mkdir -p /tmp/sdk
        curl -fsSL "${SDK_URL}" -o "/tmp/${SDK_TAR}"
        tar --zstd -xf "/tmp/${SDK_TAR}" -C /tmp/sdk --strip-components=1
        cd /tmp/sdk

        echo "==> Setting up package..."
        mkdir -p package/curl-quic
        cp -r /workspace/package/curl-quic/* package/curl-quic/

        echo "==> Generating dummy signing key..."
        openssl genrsa -out key-build 2048
        openssl rsa -in key-build -pubout -out key-build.pub

        echo "==> Compiling curl-quic..."
        make defconfig
        make package/curl-quic/compile V=s

        echo "==> Indexing repository..."
        make package/index

        echo "==> Copying output artifacts..."
        mkdir -p /workspace/dist
        find bin/packages/ -name "*.apk" -exec cp {} /workspace/dist/ \;
        find bin/packages/ -name "packages.adb" -exec cp {} /workspace/dist/ \;
        cp key-build.pub /workspace/dist/curl-quic.pub

        echo "==> Done! Artifacts are in ./dist/"
        ls -la /workspace/dist/
    '

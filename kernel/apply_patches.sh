#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$SCRIPT_DIR/config"

for patch in \
    "$PATCH_DIR/0001-arm-dts-enable-SoCFPGA-FPGA-manager-and-bridges.patch" \
    "$PATCH_DIR/0002-fpga-add-firmware-sysfs-loading-interface.patch" \
    "$PATCH_DIR/0003-fpga-update-SoCFPGA-runtime-programming-support.patch"; do
    echo "Applying $patch"
    git am "$patch"
done

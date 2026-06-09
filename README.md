# casper-altera-platforms

This repository contains the patches and runtime modifications required
to enable CASPER FPGA programming on Intel Cyclone V SoCs using Linux
FPGA Manager.

Target platform:
- DE10-Nano
- Cyclone V SoC
- Linux 6.8-rc7

This bring-up was informed by the Absolute Beginner's Guide to DE10-Nano at
[zangman/de10-nano](https://github.com/zangman/de10-nano), especially the
U-Boot and kernel build guides. This repository keeps the CASPER-specific flow
separate: it uses upstream Linux `v6.8-rc7`, applies the patches in
`kernel/config/`, and programs the FPGA at runtime through Linux FPGA Manager.

## Kernel Setup

The kernel patches in this repository are based on the upstream Linux
`v6.8-rc7` tag.

From the directory where you want to keep the Linux source tree, clone the
kernel with:

```bash
git clone --depth 1 --branch v6.8-rc7 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux-6.8-rc7
```

Set a path to this repository:

```bash
export CASPER_ALTERA_PLATFORMS=/path/to/casper-altera-platforms
```

Then apply the CASPER Intel / DE10-Nano patch set:

```bash
cd linux-6.8-rc7
git am "$CASPER_ALTERA_PLATFORMS/kernel/config/0001-arm-dts-enable-SoCFPGA-FPGA-manager-and-bridges.patch"
git am "$CASPER_ALTERA_PLATFORMS/kernel/config/0002-fpga-add-firmware-sysfs-loading-interface.patch"
git am "$CASPER_ALTERA_PLATFORMS/kernel/config/0003-fpga-update-SoCFPGA-runtime-programming-support.patch"
```

Alternatively, from inside the cloned Linux tree, run the helper script:

```bash
"$CASPER_ALTERA_PLATFORMS/kernel/apply_patches.sh"
```

Install the provided DE10-Nano kernel configuration:

```bash
cp "$CASPER_ALTERA_PLATFORMS/kernel/config/de10nano-linux-6.8-rc7.config" .config
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- olddefconfig
```

The relevant FPGA Manager options should be enabled in the resulting
configuration:

```text
CONFIG_FPGA=y
CONFIG_FPGA_MGR_SOCFPGA=y
CONFIG_FPGA_BRIDGE=y
CONFIG_SOCFPGA_FPGA_BRIDGE=y
CONFIG_FPGA_REGION=y
CONFIG_FW_LOADER=y
```

Build the kernel, device trees, and modules:

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j"$(nproc)" zImage dtbs modules
```

The expected kernel image and DE10-Nano device tree are:

```text
arch/arm/boot/zImage
arch/arm/boot/dts/intel/socfpga/socfpga_cyclone5_de10_nano.dtb
```

The `CROSS_COMPILE` prefix must match the ARM cross toolchain installed on
your build machine. Check it with:

```bash
arm-linux-gnueabihf-gcc --version
```

Other common prefixes include `arm-none-linux-gnueabihf-` and
`arm-linux-gnueabi-`.

## SD Card Bring-Up

These notes assume you already have a prepared DE10-Nano SD card or disk image
with a boot partition and Linux root filesystem. This repository does not yet
describe the full SD-card image generation flow.

The root filesystem used for this bring-up was Ubuntu Base 24.04 LTS for
`armhf`, downloaded from the Ubuntu 24.04.2 release area:

```text
https://cdimage.ubuntu.com/ubuntu-base/releases/24.04.2/release/
```

The running system may report only `Ubuntu 24.04 LTS` rather than a specific
point release. Ubuntu may publish later Noble point-release tarballs in the same
area. For example:

```text
https://cdimage.ubuntu.com/ubuntu-base/releases/24.04.2/release/ubuntu-base-24.04.3-base-armhf.tar.gz
```

Use an Ubuntu Base 24.04 `armhf` tarball from that release area to match this
bring-up closely. Newer Ubuntu Base releases may also work, but have not been
tested with this platform flow.

Set paths to the mounted boot and rootfs partitions:

```bash
export BOOT=/path/to/mounted/boot
export ROOTFS=/path/to/mounted/rootfs
```

Install the kernel image and DE10-Nano device tree:

```bash
cp arch/arm/boot/zImage "$BOOT/"
cp arch/arm/boot/dts/intel/socfpga/socfpga_cyclone5_de10_nano.dtb "$BOOT/"
```

Install kernel modules into the root filesystem:

```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
  INSTALL_MOD_PATH="$ROOTFS" modules_install
```

Ensure the firmware directory exists in the target root filesystem:

```bash
sudo mkdir -p "$ROOTFS/lib/firmware"
```

The CASPER runtime expects uploaded `.rbf` files to be placed in
`/lib/firmware` before writing the firmware filename to the FPGA Manager sysfs
attribute.

If U-Boot does not automatically find the kernel, boot to the U-Boot prompt and
restore the standard distro boot command:

```text
setenv bootcmd 'run distro_bootcmd'
saveenv
```

Those U-Boot environment changes are persistent unless the SD card environment
is overwritten.

The bootloader used for this bring-up is the Altera SoCFPGA U-Boot tree on the
`socfpga_v2024.07` branch:

```text
https://github.com/altera-fpga/u-boot-socfpga/tree/socfpga_v2024.07
```

The DE10-Nano U-Boot build normally uses `socfpga_de10_nano_defconfig` and
produces `u-boot-with-spl.sfp`. This repository does not currently build or
package U-Boot; use a known-good DE10-Nano U-Boot image or follow the external
guide in the references below.

## Expected Runtime Interface

After booting the patched kernel on the DE10-Nano, the FPGA Manager firmware
attribute should be available at:

```text
/sys/class/fpga_manager/fpga0/firmware
```

Useful runtime checks on the board:

```bash
test -e /sys/class/fpga_manager/fpga0/firmware
cat /sys/class/fpga_manager/fpga0/state
ls /sys/class/fpga_bridge/
for e in /sys/class/fpga_bridge/*/enable; do echo 1 | sudo tee "$e"; done
for s in /sys/class/fpga_bridge/*/state; do echo "$(basename "$(dirname "$s")"): $(cat "$s")"; done
```

To manually test FPGA Manager programming, copy a raw `.rbf` file to
`/lib/firmware` on the board and then run:

```bash
echo design.rbf | sudo tee /sys/class/fpga_manager/fpga0/firmware
cat /sys/class/fpga_manager/fpga0/state
```

The expected final state is `operating`.

## References

- DE10-Nano U-Boot guide:
  https://github.com/zangman/de10-nano/blob/master/docs/Building-the-Universal-Bootloader-U-Boot.md
- DE10-Nano kernel guide:
  https://github.com/zangman/de10-nano/blob/master/docs/Building-the-Kernel.md
- Altera SoCFPGA U-Boot tree:
  https://github.com/altera-fpga/u-boot-socfpga/tree/socfpga_v2024.07

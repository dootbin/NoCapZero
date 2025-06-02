# Pre-built Components Setup Guide

This guide explains how to prepare and host pre-built components for the simplified build workflow.

## Overview

The simplified workflow downloads pre-built components instead of building from source:
- U-Boot bootloader
- Linux kernel image
- Device Tree Blob (DTB)
- Kernel modules

## Building Components Locally

### 1. Build U-Boot

```bash
# Clone U-Boot (latest stable)
UBOOT_TAG=$(git ls-remote --tags --sort="v:refname" https://github.com/u-boot/u-boot.git | grep -E 'refs/tags/v20[0-9]{2}\.[0-9]{2}$' | tail -n1 | sed 's/.*refs\/tags\///')
git clone --depth 1 -b "$UBOOT_TAG" https://github.com/u-boot/u-boot.git
cd u-boot

# Build ARM Trusted Firmware first (latest stable)
ATF_TAG=$(git ls-remote --tags --sort="v:refname" https://github.com/ARM-software/arm-trusted-firmware.git | grep -E 'refs/tags/v[0-9]+\.[0-9]+(\.[0-9]+)?$' | tail -n1 | sed 's/.*refs\/tags\///')
git clone --depth 1 -b "$ATF_TAG" https://github.com/ARM-software/arm-trusted-firmware.git
cd arm-trusted-firmware
make PLAT=sun50i_h616 CROSS_COMPILE=aarch64-linux-gnu- bl31
cp build/sun50i_h616/release/bl31.bin ../
cd ..

# Configure and build U-Boot
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- orangepi_zero2w_defconfig
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- BL31=bl31.bin -j$(nproc)

# The output file will be: u-boot-sunxi-with-spl.bin
```

### 2. Build Mainline Kernel

```bash
# Clone mainline kernel
git clone --depth 1 -b v6.12 https://github.com/torvalds/linux.git
cd linux

# Use a minimal config for Orange Pi Zero 2W
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig

# Enable required options
./scripts/config --enable CONFIG_ARCH_SUNXI
./scripts/config --enable CONFIG_MACH_SUN50I
./scripts/config --enable CONFIG_USB_GADGET
./scripts/config --enable CONFIG_USB_CONFIGFS
./scripts/config --enable CONFIG_USB_ETH
./scripts/config --enable CONFIG_USB_MASS_STORAGE
./scripts/config --enable CONFIG_USB_G_SERIAL

# Build kernel, DTB, and modules
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image dtbs modules

# Install modules to a temporary directory
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=/tmp/modules modules_install

# Create modules tarball
cd /tmp
tar -czf modules.tar.gz modules/

# Output files:
# - arch/arm64/boot/Image (kernel image)
# - arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero2w.dtb (device tree)
# - /tmp/modules.tar.gz (kernel modules)
```

## Hosting Pre-built Components

### Option 1: GitHub Releases

Create a separate repository for hosting pre-built binaries:

1. Create repository: `github.com/your-org/orangepi-zero2w-prebuilts`
2. Create a release with the following files:
   - `u-boot-sunxi-with-spl.bin`
   - `Image`
   - `sun50i-h618-orangepi-zero2w.dtb`
   - `modules.tar.gz`

### Option 2: GitHub Actions Artifacts

Build components in a separate workflow and publish as artifacts:

```yaml
name: Build Components

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  workflow_dispatch:

jobs:
  build-components:
    runs-on: ubuntu-22.04
    steps:
      # ... build steps ...
      
      - name: Upload components
        uses: actions/upload-artifact@v4
        with:
          name: prebuilt-components
          path: |
            u-boot-sunxi-with-spl.bin
            Image
            sun50i-h618-orangepi-zero2w.dtb
            modules.tar.gz
          retention-days: 90
```

### Option 3: External Storage

Host files on:
- AWS S3
- Google Cloud Storage
- Azure Blob Storage
- Your own web server

## Updating the Workflow

Replace the placeholder URLs in the simplified workflow with actual URLs:

```yaml
env:
  UBOOT_URL: https://github.com/your-org/orangepi-zero2w-prebuilts/releases/latest/download/u-boot-sunxi-with-spl.bin
  KERNEL_URL: https://github.com/your-org/orangepi-zero2w-prebuilts/releases/latest/download/Image
  DTB_URL: https://github.com/your-org/orangepi-zero2w-prebuilts/releases/latest/download/sun50i-h618-orangepi-zero2w.dtb
  MODULES_URL: https://github.com/your-org/orangepi-zero2w-prebuilts/releases/latest/download/modules.tar.gz
```

## Benefits of This Approach

1. **Faster builds**: No need to compile kernel and U-Boot each time
2. **Consistent binaries**: Same tested components across builds
3. **Lower resource usage**: Minimal GitHub Actions minutes consumed
4. **Easier debugging**: Known-good components simplify troubleshooting
5. **Focus on rootfs**: Can iterate quickly on userspace configuration

## Maintenance

- Update pre-built components monthly or when security updates are released
- Test new kernel/U-Boot versions before updating URLs
- Keep multiple versions available for rollback if needed
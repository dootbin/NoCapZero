# Orange Pi Zero 2W Minimal Build System

**Supply chain secure, build-from-source Linux distribution for Orange Pi Zero 2W**

## Overview

This repository provides **automated build pipelines** that compile a minimal Arch Linux ARM system **entirely from source** for the Orange Pi Zero 2W single-board computer.

### Why Build From Source?

**Supply chain security is our primary goal.** We build all components from source to eliminate trust in pre-built binaries:

- ✅ **U-Boot bootloader**: Compiled from ARM Trusted Firmware + U-Boot source
- ✅ **Linux kernel**: Built from Orange Pi vendor kernel source
- ✅ **Kernel modules**: Compiled during kernel build
- ✅ **Root filesystem**: Assembled from Arch Linux ARM base + runtime libraries
- ⚠️ **Mali GPU driver**: Binary-only (no source available from ARM) - checksum verified

**This is intentional.** We accept longer build times (~25-30 minutes with parallel builds) to ensure we control the entire software supply chain from source code to bootable image.

### Key Features

- **Built from source**: U-Boot, kernel, and all modules compiled in CI pipeline
- **Supply chain verified**: Mali GPU driver checksums verified on every build
- **Hardware-specific kernel**: 80+ unnecessary drivers stripped - only Allwinner H618 drivers remain
- **Minimal footprint**: ~1GB runtime image (~650-700MB used), minimal kernel, aggressive firmware/locale cleanup
- **Hardware acceleration**: Mali-G31 GPU, H.264/H.265 hardware decode
- **USB gadget support**: Mass storage, networking, and serial console modes
- **Reproducible builds**: Same inputs = same outputs in GitHub Actions
- **Security focused**: Minimal attack surface, no bloat from other platforms

## Features

### Hardware Support
- ✅ Allwinner H618 SoC support
- ✅ Mali-G31 MP2 GPU acceleration
- ✅ Hardware video decode (H.264/H.265)
- ✅ WiFi 5 and Bluetooth 5.0
- ❌ Wired Ethernet (disabled - AC200 ePHY driver has build issues, see #28)
- ✅ GPIO and hardware interfaces
- ✅ Audio output (HDMI/analog)

### System Features
- ✅ Minimal Arch Linux ARM base
- ✅ Custom kernel with H618 optimizations
- ✅ USB OTG gadget modes
- ✅ Boot time: ~20 seconds
- ✅ RAM usage: ~120MB base system

### Development Stack
- ✅ Runtime libraries for static binary deployment
- ✅ GTK4 + WebKit2GTK (runtime only)
- ✅ Hardware-accelerated graphics
- ✅ Cross-compilation optimized
- ✅ Static binary support

## Build Pipeline

**All components are built from source in GitHub Actions on every run.** This is a manual, from-source build process that prioritizes supply chain security over build speed.

### Build Process (Automated in CI)

Each build performs these steps from scratch:

1. **Build ARM Trusted Firmware** - Compile BL31 for Allwinner H618
2. **Build U-Boot** - Compile bootloader with ATF integration
3. **Build Linux Kernel** - Compile Orange Pi vendor kernel (6.1-sun50iw9)
4. **Build Kernel Modules** - Compile all required drivers
5. **Download & Verify Mali Driver** - Binary-only GPU driver with SHA256 verification
6. **Assemble Root Filesystem** - Create Arch Linux ARM based system
7. **Generate Bootable Image** - Package everything into flashable SD card image

**Build time**: ~25-30 minutes wall-clock time with parallel builds (kernel compilation is the longest job at ~22 minutes)

**Why so long?** We're compiling the entire kernel, U-Boot, and ATF from source on every build for supply chain security.

**Parallel Build Architecture**: Components build simultaneously across separate jobs to maximize efficiency while staying within GitHub Actions' 14GB per-job disk limit.

## Supply Chain Security

This project takes supply chain security seriously. Here's our approach:

### What We Build From Source

| Component | Source | Why |
|-----------|--------|-----|
| ARM Trusted Firmware | ARM GitHub (official) | Closed-source but official ARM repository |
| U-Boot Bootloader | U-Boot GitHub (official) | Open source, compiled from latest stable tag |
| Linux Kernel | Orange Pi vendor kernel | Open source, H618-specific optimizations |
| Kernel Modules | Same as kernel | All drivers compiled during kernel build |
| Root Filesystem | Arch Linux ARM | Assembled from official Arch ARM base |

### What We Can't Build (Binary-Only)

| Component | Source | Verification |
|-----------|--------|--------------|
| Mali G31 GPU Driver | LibreELEC GitHub | **SHA256 checksum verified on every build** |

ARM does not provide source code for Mali GPU userspace drivers. We:
- Download from LibreELEC (trusted community source)
- Verify SHA256 checksum on every build
- Fail builds on checksum mismatch
- Maintain audit trail of checksum updates

See `checksums/README.md` for details on our verification process.

### Build Reproducibility

- All source code versions are pinned (git tags/branches)
- Build process is deterministic (same inputs = same outputs)
- Builds run in isolated GitHub Actions runners
- No manual intervention required

## Kernel Minimization

**We build a hardware-specific kernel with only Orange Pi Zero 2W drivers.**

The Orange Pi vendor kernel enables drivers for dozens of other ARM platforms by default. We aggressively strip all unnecessary drivers during the build process to create a truly minimal kernel.

### What We Remove (80+ drivers disabled)

| Category | Removed | Kept |
|----------|---------|------|
| **ARM SoC Platforms** | Tegra, Rockchip, Qualcomm, Samsung Exynos, MediaTek, Broadcom (RPi), Apple Silicon, Marvell, NXP, HiSilicon, and 20+ more | **Only Allwinner (SUNXI)** |
| **GPU Drivers** | AMD, NVIDIA, Intel, Broadcom VC4, Vivante Etnaviv | **Only Mali + basic DRM** |
| **Network Drivers** | Intel, Broadcom, Realtek, Marvell enterprise NICs | **Only USB ethernet, WiFi, Allwinner networking** |
| **Sound Drivers** | Tegra, Rockchip, Qualcomm, Samsung, Freescale audio subsystems | **Only ALSA core + Allwinner sound** |
| **Platform Features** | STAGING (unstable), COMPILE_TEST (testing-only), InfiniBand, PCMCIA, ISDN | None - all removed |

### Benefits of Minimal Kernel

- 📦 **30-40% smaller kernel image** - Less storage required, faster boot
- ⚡ **Faster compilation** - Fewer drivers = shorter build times
- 🔒 **Reduced attack surface** - Less code = fewer potential vulnerabilities
- 🎯 **Hardware-specific** - No unnecessary modules loaded at runtime
- 💾 **Lower memory usage** - Minimal kernel footprint

### Implementation

Driver removal happens during kernel build:
```bash
# Disable entire SoC platforms (30+ platforms)
./scripts/config --disable CONFIG_ARCH_TEGRA
./scripts/config --disable CONFIG_ARCH_ROCKCHIP
./scripts/config --disable CONFIG_ARCH_QCOM
# ... and 27 more

# Disable GPU drivers for other platforms
./scripts/config --disable CONFIG_DRM_AMDGPU
./scripts/config --disable CONFIG_DRM_I915
# ... etc
```

See `.github/workflows/build.yml` for the complete list of disabled drivers.

### Available Releases

Pre-built images are available in the [Releases](../../releases) section:

- **Runtime Edition**: Minimal system for deploying static binaries (~1GB image, ~650-700MB used)
- **Development Edition**: Includes on-device development tools (~1.2GB image)
- **Debug Edition**: Development edition with debug symbols and tools (~1.5GB image)

### Build Status

[![Build Status](https://github.com/NoCapZero/workflows/Build%20Images/badge.svg)](https://github.com/NoCapZero/actions)
[![Release](https://github.com/NoCapZero/workflows/Release/badge.svg)](https://github.com/NoCapZero/releases)

## Hardware Requirements

- Orange Pi Zero 2W (4GB RAM recommended)
- High-speed microSD card (32GB+, Class 10/U3)
- USB-C power supply (5V/3A)
- Mini HDMI cable and display
- USB-C cable (for gadget modes)

## Quick Start

### Download Pre-built Images

1. **Download latest release**:
   ```bash
   # Download from GitHub Releases
   wget https://github.com/NoCapZero/releases/latest/download/orangepi-zero2w-runtime.img.xz
   ```

2. **Extract and flash**:
   ```bash
   xz -d orangepi-zero2w-runtime.img.xz
   sudo dd if=orangepi-zero2w-runtime.img of=/dev/sdX bs=4M status=progress
   sync
   ```

3. **First boot**:
   - Insert SD card into Orange Pi Zero 2W
   - Connect HDMI and power
   - Default login: `root` / `orangepi`

### Deploy Your Application

Deploy static binaries to the runtime system:

```bash
# Cross-compile your Go application
export GOOS=linux GOARCH=arm64 CGO_ENABLED=1 CC=aarch64-linux-gnu-gcc
go build -ldflags="-s -w -linkmode external -extldflags '-static'" -o myapp main.go

# Deploy to Orange Pi
scp myapp root@orangepi-ip:/usr/local/bin/
ssh root@orangepi-ip "chmod +x /usr/local/bin/myapp && systemctl enable myapp"
```

## GitHub Actions Workflows

This repository contains automated workflows that **build everything from source** for supply chain security:

### Workflow Structure
```
.github/workflows/
├── build.yml              # Main parallel build-from-source workflow
└── build-components.yml   # Weekly component pre-build (for faster testing)
```

### Build Workflow (`build.yml`)

**Parallel build architecture** that builds everything from source simultaneously across multiple jobs.

**Triggered by:**
- Push to main branch
- Pull requests
- Manual workflow_dispatch (for creating releases)

**Build Architecture - Parallel Jobs:**

```
┌─────────────────────┐  ┌──────────────────┐  ┌─────────────────┐
│ Build ARM Trusted   │  │  Build Linux     │  │  Download &     │
│ Firmware (~30s)     │  │  Kernel (~22min) │  │  Verify Mali    │
└──────────┬──────────┘  └────────┬─────────┘  │  Driver (~7s)   │
           │                      │             └────────┬────────┘
           v                      │                      │
┌─────────────────────┐           │                      │
│ Build U-Boot        │           │                      │
│ Bootloader (~1.5min)│           │                      │
└──────────┬──────────┘           │                      │
           │                      │                      │
           └──────────┬───────────┴──────────────────────┘
                      v
           ┌─────────────────────────┐
           │  Assemble Images        │
           │  (runtime/dev/debug)    │
           │  Runs in parallel       │
           │  (~2-4min each)         │
           └─────────────────────────┘
```

**Total build time: ~25-30 minutes** (dominated by kernel compilation)

**Job Details:**

1. **Build ARM Trusted Firmware** (~30s, parallel)
   - Clone ARM's official ATF repository (latest stable tag)
   - Compile BL31 for Allwinner H618 SoC
   - Cross-compile for ARM64 using aarch64-linux-gnu-gcc

2. **Build Linux Kernel** (~22min, parallel)
   - Clone Orange Pi vendor kernel (6.1-sun50iw9 branch)
   - Apply custom kernel configuration from `configs/kernel-config`
   - **Strip 80+ unnecessary drivers** (Tegra, Rockchip, Qualcomm, AMD/Intel GPUs, etc.)
   - Disable problematic drivers (SUNXI_EPHY, Tegra sound, etc.)
   - Compile minimal, hardware-specific kernel Image and device tree blobs
   - Build kernel modules with structure: `modules/lib/modules/6.x.x/`
   - Package as modules.tar.gz

3. **Build U-Boot Bootloader** (~1.5min, depends on ATF)
   - Clone official U-Boot repository (latest stable tag)
   - Apply Orange Pi Zero 2W defconfig
   - Link with compiled ATF BL31
   - Cross-compile for ARM

4. **Download & Verify Mali GPU Driver** (~7s, parallel)
   - Download binary driver from LibreELEC (no source available)
   - Calculate SHA256 checksum
   - **Verify against expected checksum** (fail build on mismatch)
   - See `checksums/libmali-bifrost-g31-r16p0-gbm.sha256`

5. **Assemble Images** (3 variants in parallel, 2-4min each)
   - **Runtime Edition**: Minimal system (~1GB image)
   - **Development Edition**: With dev tools (~1.2GB image)
   - **Debug Edition**: Dev + debug symbols (~1.5GB image)

   Each assembly job:
   - Downloads Arch Linux ARM base system
   - Removes Arch's kernel modules (we provide our own)
   - Extracts compiled kernel modules from tarball
   - Installs verified Mali GPU driver
   - Removes 500+MB unnecessary firmware (keeps only Realtek/Broadcom/Allwinner)
   - Configures USB gadget support and system services
   - Creates SD card image with U-Boot, kernel, DTB, and rootfs
   - Compresses image for distribution

**Artifacts:**
- Build artifacts stored for 90 days
- Images uploaded to GitHub Releases when `release_tag` input provided

### Component Build Workflow (`build-components.yml`)

**Runs weekly on Sundays** to pre-build components for faster iteration during development.

Builds the same components as `build.yml` but stores them as a "components-latest" release. The main build workflow **does not use these** - it always builds from source. This workflow exists only to speed up testing when you need quick iteration on rootfs/image assembly scripts.

**Triggered by:**
- Weekly schedule (Sunday 00:00 UTC)
- Manual workflow_dispatch
- Push to component-related paths (kernel configs, patches)

### Creating Releases

**Use workflow_dispatch to create versioned releases:**

```bash
# Via GitHub UI:
# Actions → "Build Orange Pi Zero 2W Images" → Run workflow
# - Branch: main
# - Build variant: all
# - Release tag: v0.1.0-alpha.1

# Via gh CLI:
gh workflow run build.yml \
  --ref main \
  -f build_variant=all \
  -f release_tag=v0.1.0-alpha.1
```

**Why workflow_dispatch instead of tag triggers?**

Previously, we used `on: push: tags: v*` to trigger builds. This caused a critical problem: **GitHub Actions checks out the workflow file from the tagged commit**, not from latest main. If you tag an old commit, you get the OLD (potentially broken) workflow, leading to false positive failures.

**New approach:**
- Trigger workflow manually with `release_tag` input
- Workflow runs from main (always uses latest working code)
- Tag is created and release is published if build succeeds
- No more stale workflow issues

## Configuration Options

### Build Matrix

The GitHub Actions workflows build multiple image variants:

| Edition | Size | Use Case | Development Tools | Debug Symbols | Assembly Time |
|---------|------|----------|-------------------|---------------|---------------|
| Runtime | ~1GB (~650-700MB used) | Production deployment | ❌ | ❌ | ~2 min |
| Development | ~1.2GB | On-device development | ✅ | ❌ | ~3 min |
| Debug | ~1.5GB | Debugging and testing | ✅ | ✅ | ~4 min |

Note: Assembly time is just the image creation step. Total build time is ~25-30 minutes (dominated by 22-minute kernel compilation).

### Build Configuration

Workflows read configuration from:
- `configs/build-matrix.yml` - Defines build variants
- `configs/packages/` - Package lists for each variant
- `configs/kernel-config` - Kernel configuration
- `configs/gadget-modes.yml` - USB gadget configurations

### USB Gadget Modes

The system supports multiple USB gadget modes for different use cases:

#### Mass Storage Mode
```bash
# Enable USB storage gadget
echo "storage" > /boot/gadget-mode
reboot
# Device appears as USB drive when connected to PC
```

#### Network Mode
```bash
# Enable USB networking
echo "network" > /boot/gadget-mode
reboot
# Device provides network interface (192.168.7.2)
```

#### Serial Console Mode
```bash
# Enable USB serial console
echo "serial" > /boot/gadget-mode
reboot
# Device provides serial console access
```

## Performance Characteristics

### System Metrics (Runtime Edition)
| Metric | Value |
|--------|-------|
| Boot time | ~20 seconds |
| Base RAM usage | ~120MB |
| Root filesystem partition | 1GB (650-700MB used after aggressive cleanup) |
| Kernel size | ~8MB (minimal, H618-specific only) |
| Available RAM (4GB model) | ~3.8GB |

### Graphics Performance
| Feature | Status |
|---------|--------|
| OpenGL ES 3.2 | ✅ Hardware accelerated |
| Vulkan 1.1 | ✅ Supported |
| 1080p60 video decode | ✅ Hardware accelerated |
| 4K30 video decode | ✅ Hardware accelerated |
| WebGL | ✅ Hardware accelerated |

## Development Environment

### Cross-compilation Setup

For developing applications that target Orange Pi Zero 2W:

```bash
# Install cross-compiler
sudo apt install gcc-aarch64-linux-gnu

# Set environment for static linking
export GOOS=linux
export GOARCH=arm64  
export CGO_ENABLED=1
export CC=aarch64-linux-gnu-gcc

# Build static binary
go build -ldflags="-s -w -linkmode external -extldflags '-static'" -o myapp main.go

# Verify it's statically linked
file myapp
ldd myapp  # Should show "not a dynamic executable"
```

### Application Template

Example Go application using GTK4 and WebKit:

```go
package main

import (
    "github.com/diamondburned/gotk4/pkg/gtk/v4"
    "github.com/diamondburned/gotk4/pkg/webkit/v6"
)

func main() {
    app := gtk.NewApplication("com.example.app", 0)
    app.ConnectActivate(func() {
        window := gtk.NewApplicationWindow(app)
        webview := webkit.NewWebView()
        
        // Enable hardware acceleration
        settings := webview.Settings()
        settings.SetEnableWebGL(true)
        settings.SetHardwareAccelerationPolicy(webkit.HardwareAccelerationPolicyAlways)
        
        webview.LoadURI("http://localhost:3000")
        window.SetChild(webview)
        window.Fullscreen()
        window.Present()
    })
    
    app.Run(nil)
}
```

### Deployment Automation

```bash
# GitHub Actions workflow for app deployment
name: Deploy to Orange Pi
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      
      - name: Cross-compile
        run: |
          sudo apt install gcc-aarch64-linux-gnu
          export GOOS=linux GOARCH=arm64 CGO_ENABLED=1 CC=aarch64-linux-gnu-gcc
          go build -ldflags="-s -w -linkmode external -extldflags '-static'" -o myapp
          
      - name: Deploy to device
        run: |
          scp myapp ${{ secrets.ORANGEPI_HOST }}:/usr/local/bin/
          ssh ${{ secrets.ORANGEPI_HOST }} "systemctl restart myapp"
```

## Customization

### Forking for Custom Builds

To create custom images for your specific use case:

1. **Fork this repository**
2. **Modify build configuration**:
   ```yaml
   # configs/build-matrix.yml
   variants:
     custom:
       packages: configs/packages/custom.list
       size_limit: 300MB
       features:
         - gpio_support
         - custom_drivers
   ```

3. **Add custom packages**:
   ```bash
   # configs/packages/custom.list
   base
   linux-firmware
   gtk4
   webkit2gtk-4.1
   your-custom-package
   ```

4. **Push changes** - GitHub Actions will automatically build your custom image

### Custom Kernel Configuration

```bash
# Add custom kernel patches
mkdir -p patches/kernel/custom/
# Place your .patch files here

# Modify kernel config
# Edit configs/kernel-config

# GitHub Actions will apply patches and build custom kernel
```

### Adding System Services

```yaml
# configs/services.yml
services:
  - name: myapp
    binary: /usr/local/bin/myapp
    user: root
    restart: always
    environment:
      - DISPLAY=:0
```

## Troubleshooting

### Common Issues

**Build fails with missing pre-built components:**
```bash
# Ensure components-latest release exists
# Run the build-components workflow manually if needed
```

**Build fails with cross-compiler errors:**
```bash
# Install cross-compilation toolchain
sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
```

**SD card won't boot:**
```bash
# Check partition table
sudo fdisk -l /dev/sdX
# Verify U-Boot installation
sudo dd if=/dev/sdX bs=512 skip=16 count=1 | hexdump -C
```

**No video output:**
```bash
# Check HDMI connection
# Try different HDMI cable/port
# Verify kernel has DRM drivers enabled
```

**USB gadget not working:**
```bash
# Check USB cable (must support data)
# Verify gadget mode setting
cat /boot/gadget-mode
# Check kernel modules
lsmod | grep dwc2
```

### Debug Mode

```bash
# Build with debug symbols
./build.sh --debug

# Enable verbose boot
# Edit /boot/cmdline.txt, remove 'quiet'

# Access via serial console
screen /dev/ttyUSB0 115200
```

## Hardware Acceleration Testing

### GPU Test
```bash
# Install test utilities
pacman -S mesa-utils

# Test OpenGL
glxinfo | grep renderer
glmark2-es2

# Test EGL
eglinfo
```

### Video Decode Test
```bash
# Install VA-API utilities
pacman -S libva-utils

# Test hardware decode
vainfo
ffmpeg -hwaccel vaapi -i test.mp4 -f null -
```

## Contributing

### Development Setup

```bash
# Clone repository  
git clone https://github.com/your-org/orangepi-zero2w-build.git
cd orangepi-zero2w-build

# Test workflows locally using act
# Install: https://github.com/nektos/act
act -j build

# Or run specific workflow
act -j build -e .github/events/push.json
```

### Adding New Features

1. **Create feature branch** from `main`
2. **Add workflow modifications** in `.github/workflows/`
3. **Update build configurations** in `configs/`
4. **Test locally** with act or in fork
5. **Submit pull request** with:
   - Description of changes
   - Test results on actual hardware
   - Performance impact analysis

### Testing Changes

```bash
# Run workflow tests
act -j test

# Test on actual hardware (requires Orange Pi Zero 2W)
# Flash test image and run validation suite
./scripts/test-hardware.sh /dev/sdX
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Hardware Sources

Mali GPU drivers are provided by ARM Limited under their standard license terms.
Video decode acceleration uses the open-source Cedrus driver.

## Acknowledgments

- Orange Pi development team for H618 support
- Arch Linux ARM project for base system
- ARM Limited for Mali driver documentation
- Linux-sunxi community for Allwinner support

## Support

- **Issues**: [GitHub Issue Tracker](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)  
- **Releases**: [Latest Builds](../../releases)
- **Actions**: [Build Status](../../actions)
- **Hardware**: Orange Pi official forums
- **Documentation**: See `docs/` directory in repository

### Reporting Issues

When reporting issues, please include:
- Orange Pi Zero 2W hardware revision
- Image version and edition used
- Complete error logs
- Steps to reproduce
- Hardware setup (power supply, SD card, etc.)

---

**Note**: This repository contains GitHub Actions workflows for automated building. The generated images create minimal embedded Linux distributions optimized for Orange Pi Zero 2W hardware. All builds are performed in GitHub's cloud infrastructure and released automatically.
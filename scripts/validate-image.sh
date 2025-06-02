#!/bin/bash
#
# Script to validate Orange Pi Zero 2W SD card images
#
set -e

if [ $# -ne 1 ]; then
  echo "Usage: $0 <image_file>"
  exit 1
fi

IMAGE="$1"

if [ ! -f "$IMAGE" ]; then
  echo "Error: Image file not found: $IMAGE"
  exit 1
fi

echo "Validating image: $IMAGE"

# Check file size
SIZE=$(stat -c%s "$IMAGE")
SIZE_MB=$((SIZE / 1024 / 1024))
echo "Image size: ${SIZE_MB}MB"

# Mount image and check contents
echo "Checking image partitions..."
LOOP_DEV=$(losetup -f --show -P "$IMAGE")

# Check boot partition
if [ -e "${LOOP_DEV}p1" ]; then
  echo "Boot partition found: ${LOOP_DEV}p1"
  
  # Mount boot partition
  BOOT_MNT=$(mktemp -d)
  mount "${LOOP_DEV}p1" "$BOOT_MNT"
  
  # Check essential boot files
  echo "Checking boot files..."
  if [ -f "$BOOT_MNT/Image" ]; then
    echo "✓ Kernel Image found"
  else
    echo "✗ Kernel Image missing"
    ERRORS=1
  fi
  
  if [ -f "$BOOT_MNT/dtb/allwinner/sun50i-h618-orangepi-zero2w.dtb" ]; then
    echo "✓ Device Tree found"
  else
    echo "✗ Device Tree missing"
    ERRORS=1
  fi
  
  if [ -f "$BOOT_MNT/extlinux/extlinux.conf" ]; then
    echo "✓ Boot configuration found"
  else
    echo "✗ Boot configuration missing"
    ERRORS=1
  fi
  
  if [ -f "$BOOT_MNT/gadget-mode" ]; then
    GADGET_MODE=$(cat "$BOOT_MNT/gadget-mode")
    echo "✓ Gadget mode: $GADGET_MODE"
  else
    echo "✗ Gadget mode configuration missing"
    ERRORS=1
  fi
  
  umount "$BOOT_MNT"
  rmdir "$BOOT_MNT"
else
  echo "✗ Boot partition not found"
  ERRORS=1
fi

# Check root partition
if [ -e "${LOOP_DEV}p2" ]; then
  echo "Root partition found: ${LOOP_DEV}p2"
  
  # Mount root partition
  ROOT_MNT=$(mktemp -d)
  mount "${LOOP_DEV}p2" "$ROOT_MNT"
  
  # Check essential root files
  echo "Checking root filesystem..."
  if [ -d "$ROOT_MNT/lib/modules" ]; then
    echo "✓ Kernel modules found"
  else
    echo "✗ Kernel modules missing"
    ERRORS=1
  fi
  
  if [ -f "$ROOT_MNT/usr/lib/libmali.so" ]; then
    echo "✓ Mali GPU driver found"
  else
    echo "✗ Mali GPU driver missing"
    ERRORS=1
  fi
  
  if [ -f "$ROOT_MNT/usr/local/bin/setup-gadget.sh" ]; then
    echo "✓ Gadget setup script found"
  else
    echo "✗ Gadget setup script missing"
    ERRORS=1
  fi
  
  if [ -f "$ROOT_MNT/usr/local/bin/firstboot.sh" ]; then
    echo "✓ First boot script found"
  else
    echo "✗ First boot script missing"
    ERRORS=1
  fi
  
  umount "$ROOT_MNT"
  rmdir "$ROOT_MNT"
else
  echo "✗ Root partition not found"
  ERRORS=1
fi

# Clean up
losetup -d "$LOOP_DEV"

# Check for U-Boot
echo "Checking U-Boot..."
dd if="$IMAGE" bs=1024 skip=8 count=1 2>/dev/null | hexdump -C | grep -q "U-Boot"
if [ $? -eq 0 ]; then
  echo "✓ U-Boot bootloader found"
else
  echo "✗ U-Boot bootloader missing or invalid"
  ERRORS=1
fi

# Report validation status
if [ -z "$ERRORS" ]; then
  echo "✅ Image validation successful: $IMAGE"
  exit 0
else
  echo "❌ Image validation failed: $IMAGE"
  exit 1
fi
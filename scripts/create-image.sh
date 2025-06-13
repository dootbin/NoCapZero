#!/bin/bash
#
# Script to create bootable SD card image for Orange Pi Zero 2W
#
set -e

# Default values
OUTPUT="orangepi-zero2w.img"
VARIANT="runtime"
ROOTFS_SIZE=400  # MB
BOOT_SIZE=128    # MB

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --rootfs)
      ROOTFS="$2"
      shift 2
      ;;
    --uboot)
      UBOOT="$2"
      shift 2
      ;;
    --kernel)
      KERNEL="$2"
      shift 2
      ;;
    --dtb)
      DTB="$2"
      shift 2
      ;;
    --variant)
      VARIANT="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$ROOTFS" ] || [ -z "$UBOOT" ] || [ -z "$KERNEL" ] || [ -z "$DTB" ]; then
  echo "Error: Required parameters missing"
  echo "Usage: $0 --rootfs <rootfs_dir> --uboot <uboot_bin> --kernel <kernel_image> --dtb <dtb_file> [--variant <variant>] [--output <output_img>]"
  exit 1
fi

# Adjust rootfs size based on variant
case $VARIANT in
  runtime)
    ROOTFS_SIZE=200
    ;;
  development)
    ROOTFS_SIZE=600
    ;;
  debug)
    ROOTFS_SIZE=800
    ;;
esac

# Calculate image size (in MB) and sector count
IMAGE_SIZE=$((BOOT_SIZE + ROOTFS_SIZE))
SECTORS=$((IMAGE_SIZE * 2048))  # 512-byte sectors

echo "Creating image for variant: $VARIANT"
echo "Image size: ${IMAGE_SIZE}MB (boot: ${BOOT_SIZE}MB, rootfs: ${ROOTFS_SIZE}MB)"

# Create empty image file
dd if=/dev/zero of="$OUTPUT" bs=1M count="$IMAGE_SIZE" status=progress

# Set up loop device
LOOP_DEV=$(losetup -f --show "$OUTPUT")
echo "Using loop device: $LOOP_DEV"

# Create partition table
parted -s "$LOOP_DEV" mklabel msdos
parted -s "$LOOP_DEV" mkpart primary fat32 1MiB "$((BOOT_SIZE + 1))"MiB
parted -s "$LOOP_DEV" mkpart primary ext4 "$((BOOT_SIZE + 1))"MiB 100%
parted -s "$LOOP_DEV" set 1 boot on

# Get partition devices
BOOT_DEV="${LOOP_DEV}p1"
ROOTFS_DEV="${LOOP_DEV}p2"

# Format partitions
mkfs.vfat -F 32 -n "BOOT" "$BOOT_DEV"
mkfs.ext4 -L "rootfs" "$ROOTFS_DEV"

# Mount partitions
BOOT_MNT=$(mktemp -d)
ROOTFS_MNT=$(mktemp -d)
mount "$BOOT_DEV" "$BOOT_MNT"
mount "$ROOTFS_DEV" "$ROOTFS_MNT"

# Install U-Boot
dd if="$UBOOT" of="$LOOP_DEV" bs=1024 seek=8 conv=notrunc

# Copy boot files
mkdir -p "$BOOT_MNT/extlinux"
cat > "$BOOT_MNT/extlinux/extlinux.conf" << EOF
DEFAULT orangepi
LABEL orangepi
  LINUX /Image
  FDT /dtb/allwinner/sun50i-h618-orangepi-zero2w.dtb
  APPEND root=/dev/mmcblk0p2 rw rootwait console=ttyS0,115200 quiet
EOF

cp "$KERNEL" "$BOOT_MNT/Image"
mkdir -p "$BOOT_MNT/dtb/allwinner"
cp "$DTB" "$BOOT_MNT/dtb/allwinner/"

# Copy rootfs files
rsync -aHAXx "$ROOTFS"/ "$ROOTFS_MNT"/

# Create gadget mode setting file
echo "network" > "$BOOT_MNT/gadget-mode"

# Unmount and clean up
sync
umount "$BOOT_MNT"
umount "$ROOTFS_MNT"
rmdir "$BOOT_MNT"
rmdir "$ROOTFS_MNT"
losetup -d "$LOOP_DEV"

echo "Image created successfully: $OUTPUT"
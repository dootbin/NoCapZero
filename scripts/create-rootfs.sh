#!/bin/bash
#
# Script to create root filesystem for Orange Pi Zero 2W
#
set -e

# Default values
OUTPUT="/tmp/rootfs"
VARIANT="runtime"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --variant)
      VARIANT="$2"
      shift 2
      ;;
    --arch-tarball)
      ARCH_TARBALL="$2"
      shift 2
      ;;
    --kernel-modules)
      KERNEL_MODULES="$2"
      shift 2
      ;;
    --mali-driver)
      MALI_DRIVER="$2"
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
if [ -z "$ARCH_TARBALL" ] || [ -z "$KERNEL_MODULES" ] || [ -z "$MALI_DRIVER" ]; then
  echo "Error: Required parameters missing"
  echo "Usage: $0 --variant <variant> --arch-tarball <tarball> --kernel-modules <modules_dir> --mali-driver <driver_path> [--output <output_dir>]"
  exit 1
fi

# Package lists based on variant
RUNTIME_PACKAGES="base linux-firmware mesa libdrm gtk4 webkit2gtk openssh wpa_supplicant"
DEVELOPMENT_PACKAGES="$RUNTIME_PACKAGES git gcc make cmake go"
DEBUG_PACKAGES="$DEVELOPMENT_PACKAGES gdb valgrind strace perf"

# Create clean output directory
rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

echo "Creating root filesystem for variant: $VARIANT"

# Extract base system
echo "Extracting Arch Linux ARM base system..."
tar -xf "$ARCH_TARBALL" -C "$OUTPUT"

# Install kernel modules
echo "Installing kernel modules..."
mkdir -p "$OUTPUT/lib/modules"
cp -a "$KERNEL_MODULES/lib/modules/"* "$OUTPUT/lib/modules/"

# Install Mali GPU driver
echo "Installing Mali GPU driver..."
mkdir -p "$OUTPUT/usr/lib"
cp "$MALI_DRIVER" "$OUTPUT/usr/lib/libmali.so"
ln -sf libmali.so "$OUTPUT/usr/lib/libEGL.so.1"
ln -sf libmali.so "$OUTPUT/usr/lib/libGLESv2.so.2"
ln -sf libmali.so "$OUTPUT/usr/lib/libgbm.so.1"

# Create necessary configuration based on variant
mkdir -p "$OUTPUT/etc/systemd/system/multi-user.target.wants"

# Create USB gadget service
cat > "$OUTPUT/etc/systemd/system/usb-gadget.service" << EOF
[Unit]
Description=USB Gadget Mode Setup
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-gadget.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

ln -sf ../usb-gadget.service "$OUTPUT/etc/systemd/system/multi-user.target.wants/usb-gadget.service"

# Create gadget setup script
mkdir -p "$OUTPUT/usr/local/bin"
cat > "$OUTPUT/usr/local/bin/setup-gadget.sh" << EOF
#!/bin/bash
# Script to set up USB gadget mode based on /boot/gadget-mode

if [ -f /boot/gadget-mode ]; then
  MODE=\$(cat /boot/gadget-mode)
  echo "Setting up USB gadget mode: \$MODE"
  
  modprobe libcomposite
  
  case \$MODE in
    storage)
      modprobe g_mass_storage stall=0 removable=1 file=/dev/mmcblk0
      ;;
    network)
      modprobe g_ether dev_addr=00:22:82:ff:ff:01 host_addr=00:22:82:ff:ff:02
      ;;
    serial)
      modprobe g_serial use_acm=0
      ;;
    *)
      echo "Unknown gadget mode: \$MODE"
      ;;
  esac
fi
EOF

chmod +x "$OUTPUT/usr/local/bin/setup-gadget.sh"

# Create first boot setup
cat > "$OUTPUT/etc/systemd/system/firstboot.service" << EOF
[Unit]
Description=First Boot Setup
After=local-fs.target
ConditionPathExists=!/var/lib/firstboot-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/firstboot.sh
ExecStartPost=/usr/bin/touch /var/lib/firstboot-done
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

ln -sf ../firstboot.service "$OUTPUT/etc/systemd/system/multi-user.target.wants/firstboot.service"

cat > "$OUTPUT/usr/local/bin/firstboot.sh" << EOF
#!/bin/bash
# First boot setup script

# Resize root partition to fill SD card
echo "Resizing root partition..."
/usr/bin/resize2fs /dev/mmcblk0p2

# Generate SSH host keys
echo "Generating SSH host keys..."
ssh-keygen -A

# Set hostname
echo "orangepi-zero2w" > /etc/hostname
EOF

chmod +x "$OUTPUT/usr/local/bin/firstboot.sh"

# Set root password
echo "Setting root password..."
echo 'root:orangepi' | chroot "$OUTPUT" chpasswd

# Clean up based on variant
if [ "$VARIANT" = "runtime" ]; then
  echo "Cleaning up for runtime edition..."
  rm -rf "$OUTPUT/usr/include"
  rm -rf "$OUTPUT/usr/share/man"
  rm -rf "$OUTPUT/usr/share/doc"
fi

echo "Root filesystem created successfully at: $OUTPUT"
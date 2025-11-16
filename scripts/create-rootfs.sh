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
sudo rm -rf "$OUTPUT"
sudo mkdir -p "$OUTPUT"

echo "Creating root filesystem for variant: $VARIANT"

# Extract base system
echo "Extracting Arch Linux ARM base system..."
sudo tar -xpf "$ARCH_TARBALL" -C "$OUTPUT"

# Install kernel modules
echo "Installing kernel modules..."
# Remove Arch Linux's kernel modules first (we provide our own custom kernel)
# Note: /lib is typically a symlink to /usr/lib in Arch, so don't mkdir it!
if [ -e "$OUTPUT/lib/modules" ]; then
  sudo rm -rf "$OUTPUT/lib/modules"
fi
# Extract modules directly to rootfs (tarball contains lib/modules/... structure)
sudo tar -xzf "$KERNEL_MODULES" -C "$OUTPUT"

# Install Mali GPU driver
echo "Installing Mali GPU driver..."
sudo mkdir -p "$OUTPUT/usr/lib"
sudo cp "$MALI_DRIVER" "$OUTPUT/usr/lib/libmali.so"
sudo ln -sf libmali.so "$OUTPUT/usr/lib/libEGL.so.1"
sudo ln -sf libmali.so "$OUTPUT/usr/lib/libGLESv2.so.2"
sudo ln -sf libmali.so "$OUTPUT/usr/lib/libgbm.so.1"

# Create necessary configuration based on variant
sudo mkdir -p "$OUTPUT/etc/systemd/system/multi-user.target.wants"

# Create USB gadget service
sudo tee "$OUTPUT/etc/systemd/system/usb-gadget.service" > /dev/null << EOF
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

sudo ln -sf ../usb-gadget.service "$OUTPUT/etc/systemd/system/multi-user.target.wants/usb-gadget.service"

# Create gadget setup script
sudo mkdir -p "$OUTPUT/usr/local/bin"
sudo tee "$OUTPUT/usr/local/bin/setup-gadget.sh" > /dev/null << EOF
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

sudo chmod +x "$OUTPUT/usr/local/bin/setup-gadget.sh"

# Create first boot setup
sudo tee "$OUTPUT/etc/systemd/system/firstboot.service" > /dev/null << EOF
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

sudo ln -sf ../firstboot.service "$OUTPUT/etc/systemd/system/multi-user.target.wants/firstboot.service"

sudo tee "$OUTPUT/usr/local/bin/firstboot.sh" > /dev/null << EOF
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

sudo chmod +x "$OUTPUT/usr/local/bin/firstboot.sh"

# Set root password
echo "Setting root password..."
echo 'root:orangepi' | sudo chroot "$OUTPUT" chpasswd

# CRITICAL: Remove ALL firmware except what Orange Pi Zero 2W actually needs
# Orange Pi Zero 2W uses:
# - Realtek or Broadcom WiFi/BT (rtl* or brcm*)
# - Allwinner-specific firmware
# Remove 500+MB of unnecessary firmware for other devices
# This applies to ALL variants to save space
if [ -d "$OUTPUT/usr/lib/firmware" ]; then
  echo "Removing unnecessary firmware (keeping only Realtek/Broadcom/Allwinner)..."
  cd "$OUTPUT/usr/lib/firmware"
  # Keep only what we need, remove everything else
  sudo find . -mindepth 1 -maxdepth 1 \
    ! -name 'rtl*' \
    ! -name 'brcm*' \
    ! -name 'regulatory.db*' \
    -exec rm -rf {} +
  cd - > /dev/null
fi

# Clean up based on variant
if [ "$VARIANT" = "runtime" ]; then
  echo "Cleaning up for runtime edition (aggressive minimal system)..."

  # Remove development files
  sudo rm -rf "$OUTPUT/usr/include"
  sudo find "$OUTPUT/usr/lib" -name "*.a" -delete  # Static libraries

  # Remove documentation
  sudo rm -rf "$OUTPUT/usr/share/man"
  sudo rm -rf "$OUTPUT/usr/share/doc"
  sudo rm -rf "$OUTPUT/usr/share/info"
  sudo rm -rf "$OUTPUT/usr/share/gtk-doc"

  # Remove all locales except C/en_US
  sudo find "$OUTPUT/usr/share/locale" -mindepth 1 -maxdepth 1 ! -name 'en_US' ! -name 'locale.alias' -exec rm -rf {} +
  sudo find "$OUTPUT/usr/share/i18n/locales" -mindepth 1 -maxdepth 1 ! -name 'en_US' ! -name 'en_GB' ! -name 'C' ! -name 'POSIX' ! -name 'i18n*' ! -name 'iso*' ! -name 'translit*' -exec rm -rf {} + 2>/dev/null || true

  # Remove package manager cache
  sudo rm -rf "$OUTPUT/var/cache/pacman"
  sudo rm -rf "$OUTPUT/var/lib/pacman/sync"

  # Remove systemd documentation
  sudo rm -rf "$OUTPUT/usr/share/factory"

  # Remove bash completion
  sudo rm -rf "$OUTPUT/usr/share/bash-completion"

  # Clean up logs
  sudo rm -rf "$OUTPUT/var/log"/*

  echo "Runtime cleanup complete - minimal barebones system"
fi

echo "Root filesystem created successfully at: $OUTPUT"
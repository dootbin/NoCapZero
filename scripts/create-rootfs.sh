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
sudo rm -rf "$OUTPUT/lib/modules"
sudo mkdir -p "$OUTPUT/lib/modules"
# Extract modules tarball to temporary location
TEMP_MODULES="/tmp/kernel-modules-extract"
mkdir -p "$TEMP_MODULES"
sudo tar -xzf "$KERNEL_MODULES" -C "$TEMP_MODULES"
# Copy modules to rootfs (tarball has modules/lib/modules/ structure)
sudo cp -a "$TEMP_MODULES/modules/lib/modules/"* "$OUTPUT/lib/modules/"
# Clean up
rm -rf "$TEMP_MODULES"

# Install Mali GPU driver
echo "Installing Mali GPU driver..."
sudo mkdir -p "$OUTPUT/usr/lib"
sudo cp "$MALI_DRIVER" "$OUTPUT/usr/lib/libmali.so"
sudo ln -sf libmali.so "$OUTPUT/usr/lib/libEGL.so.1"
sudo ln -sf libmali.so "$OUTPUT/usr/lib/libGLESv2.so.2"
sudo ln -sf libmali.so "$OUTPUT/usr/lib/libgbm.so.1"

# Install packages based on variant
echo "Installing packages for $VARIANT variant..."

# Get the script directory to find package lists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_LIST="$SCRIPT_DIR/../configs/packages/${VARIANT}.list"

if [ ! -f "$PACKAGE_LIST" ]; then
  echo "ERROR: Package list not found: $PACKAGE_LIST"
  exit 1
fi

# Read package list (skip empty lines and comments)
PACKAGES=$(grep -v '^#' "$PACKAGE_LIST" | grep -v '^[[:space:]]*$' | tr '\n' ' ')
echo "Packages to install: $PACKAGES"

# For now, skip additional package installation
# The base Arch Linux ARM tarball already has systemd
# We'll install SSH and other packages on first boot via pacman
echo "Note: Using base Arch Linux ARM system"
echo "Additional packages ($PACKAGES) should be installed on first boot"

# Create a first-boot script to install packages
sudo mkdir -p "$OUTPUT/usr/local/bin"
sudo tee "$OUTPUT/usr/local/bin/install-packages.sh" > /dev/null << PKGEOF
#!/bin/bash
# Auto-install packages on first boot if network is available

LOGFILE="/var/log/firstboot.log"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] \$*" | tee -a "\$LOGFILE"
}

log "Checking network connectivity..."
if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
  log "✓ Network available"
  log "Installing packages: $PACKAGES"

  if pacman -Sy --noconfirm --needed $PACKAGES 2>&1 | tee -a "\$LOGFILE"; then
    touch /var/lib/packages-installed
    log "✓ All packages installed successfully"
    log "Installed packages:"
    pacman -Q $PACKAGES | tee -a "\$LOGFILE"
    exit 0
  else
    log "✗ Package installation failed"
    exit 1
  fi
else
  log "✗ No network connectivity - skipping package installation"
  log "Cannot reach 8.8.8.8"
  exit 1
fi
PKGEOF

sudo chmod +x "$OUTPUT/usr/local/bin/install-packages.sh"

# Note: We skip package installation during image build
# Packages will be installed on first boot when network is available

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
# First boot setup script with detailed logging

LOGFILE="/var/log/firstboot.log"
exec > >(tee -a "\$LOGFILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] \$*"
}

log "=========================================="
log "First Boot Setup Started"
log "=========================================="

# Resize root partition to fill SD card
log "Resizing root partition..."
if /usr/bin/resize2fs /dev/mmcblk0p2; then
    log "✓ Root partition resized successfully"
else
    log "✗ Failed to resize root partition"
fi

# Set hostname
log "Setting hostname..."
echo "orangepi-zero2w" > /etc/hostname
log "✓ Hostname set to orangepi-zero2w"

# Configure WiFi if wifi.conf exists on boot partition
if [ -f /boot/wifi.conf ]; then
  log "Found WiFi configuration file"
  log "Reading WiFi credentials..."
  source /boot/wifi.conf

  if [ -n "\$WIFI_SSID" ] && [ -n "\$WIFI_PSK" ]; then
    log "WiFi SSID: \$WIFI_SSID"

    # Install wpa_supplicant if not present
    if ! command -v wpa_passphrase >/dev/null 2>&1; then
      log "Installing wpa_supplicant and dhcpcd..."
      log "Running: pacman -Sy --noconfirm wpa_supplicant dhcpcd iw"

      if pacman -Sy --noconfirm wpa_supplicant dhcpcd iw 2>&1 | tee -a "\$LOGFILE"; then
        log "✓ wpa_supplicant and dhcpcd installed"
      else
        log "✗ Failed to install wpa_supplicant/dhcpcd"
        log "Network NOT available - cannot install packages"
        exit 1
      fi
    else
      log "✓ wpa_supplicant already present"
    fi

    # Create wpa_supplicant configuration
    log "Creating wpa_supplicant configuration..."
    if wpa_passphrase "\$WIFI_SSID" "\$WIFI_PSK" > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf; then
      log "✓ wpa_supplicant config created"
    else
      log "✗ Failed to create wpa_supplicant config"
    fi

    # Enable and start WiFi services
    log "Enabling WiFi services..."
    systemctl enable wpa_supplicant@wlan0
    systemctl start wpa_supplicant@wlan0
    log "✓ wpa_supplicant started"

    systemctl enable dhcpcd@wlan0
    systemctl start dhcpcd@wlan0
    log "✓ dhcpcd started"

    # Wait for connection
    log "Waiting for WiFi connection (max 30s)..."
    for i in {1..30}; do
      if systemctl is-active --quiet wpa_supplicant@wlan0 && ip addr show wlan0 | grep -q "inet "; then
        IP=\$(ip -4 addr show wlan0 | grep inet | awk '{print \$2}')
        log "✓ WiFi connected! IP: \$IP"
        break
      fi
      sleep 1
      if [ \$i -eq 30 ]; then
        log "✗ WiFi connection timeout after 30s"
        log "wpa_supplicant status:"
        systemctl status wpa_supplicant@wlan0 | tee -a "\$LOGFILE"
        log "wlan0 interface:"
        ip addr show wlan0 | tee -a "\$LOGFILE"
      fi
    done

    log "WiFi configuration complete for SSID: \$WIFI_SSID"
  else
    log "✗ WiFi config file missing WIFI_SSID or WIFI_PSK"
  fi
else
  log "No WiFi configuration file found at /boot/wifi.conf"
  log "Skipping WiFi setup"
fi

# Install additional packages if network is available and not already installed
if [ ! -f /var/lib/packages-installed ]; then
  log "Installing additional packages..."
  if /usr/local/bin/install-packages.sh; then
    log "✓ Packages installed successfully"
  else
    log "✗ Package installation failed (check network)"
  fi
else
  log "Packages already installed (marker file exists)"
fi

# Generate SSH host keys (after openssh is installed)
if command -v ssh-keygen >/dev/null 2>&1; then
  log "Generating SSH host keys..."
  if ssh-keygen -A; then
    log "✓ SSH host keys generated"
  else
    log "✗ Failed to generate SSH host keys"
  fi

  log "Enabling SSH service..."
  systemctl enable sshd
  systemctl start sshd

  if systemctl is-active --quiet sshd; then
    log "✓ SSH service started successfully"
  else
    log "✗ SSH service failed to start"
    systemctl status sshd | tee -a "\$LOGFILE"
  fi
else
  log "✗ ssh-keygen not found - openssh not installed"
fi

log "=========================================="
log "First Boot Setup Complete"
log "=========================================="
log "Summary:"
log "  Hostname: orangepi-zero2w"
log "  WiFi SSID: \${WIFI_SSID:-not configured}"
log "  WiFi IP: \$(ip -4 addr show wlan0 2>/dev/null | grep inet | awk '{print \$2}' || echo 'not connected')"
log "  SSH Status: \$(systemctl is-active sshd 2>/dev/null || echo 'not running')"
log "  Log file: \$LOGFILE"
log "=========================================="
EOF

sudo chmod +x "$OUTPUT/usr/local/bin/firstboot.sh"

# Set root password (generate hash and write to shadow file)
echo "Setting root password..."
# Generate password hash for 'orangepi'
PASS_HASH=$(openssl passwd -6 "orangepi")
# Update shadow file with the hash
sudo sed -i "s|^root:[^:]*:|root:$PASS_HASH:|" "$OUTPUT/etc/shadow"

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
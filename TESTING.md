# Testing Orange Pi Zero 2W Images

## Manual Testing Guide

### Prerequisites
- Orange Pi Zero 2W board
- microSD card (8GB+)
- USB-C cable (data-capable, not charge-only!)
- balenaEtcher or similar
- Computer with WiFi for testing

### Step 1: Download Latest Image

```bash
# Find latest successful build
gh run list --workflow=build.yml --status=success --limit 1

# Download it (replace RUN_ID with the number from above)
gh run download <RUN_ID> -n orangepi-zero2w-runtime
```

### Step 2: Flash Image

1. Open balenaEtcher
2. Select `orangepi-zero2w-runtime.img.xz`
3. Select your SD card
4. Flash!

### Step 3: Configure WiFi (Before First Boot)

After flashing, the SD card will have a `BOOT` partition. Create a file called `wifi.conf`:

**On macOS/Linux:**
```bash
# Mount the boot partition (it should auto-mount after flashing)
# The BOOT partition should be visible in Finder/File Manager

# Create wifi.conf
cat > /Volumes/BOOT/wifi.conf << 'EOF'
WIFI_SSID="YourNetworkName"
WIFI_PSK="YourPassword"
EOF

# Eject the SD card
```

**On Windows:**
1. The BOOT drive should appear in Explorer
2. Create a new text file called `wifi.conf` (not `wifi.conf.txt`!)
3. Add these two lines:
   ```
   WIFI_SSID="YourNetworkName"
   WIFI_PSK="YourPassword"
   ```
4. Save and eject

### Step 4: Boot and Test

1. Insert SD card into Orange Pi Zero 2W
2. Connect power (USB-C, 5V/3A recommended)
3. Wait ~60 seconds for first boot (it's installing packages from the internet)

**First boot does:**
- Resizes root partition to fill SD card
- Reads WiFi config and connects
- Installs packages: openssh, wpa_supplicant, dhcpcd, and others
- Generates SSH keys
- Enables SSH service

### Step 5: Find Device IP

**Option A: Check your router**
- Look for device named `orangepi-zero2w`

**Option B: Use nmap**
```bash
nmap -sn 192.168.1.0/24 | grep -B 2 orangepi
```

**Option C: Connect via USB (if WiFi fails)**
- Connect Orange Pi to computer via USB-C (data cable!)
- SSH to `192.168.7.2` (if USB gadget network mode is enabled)

### Step 6: SSH In

```bash
ssh root@<device-ip>
# Password: orangepi
```

### Step 7: Verify Installation

Once logged in via SSH:

```bash
# Check system
uname -a

# Check if packages installed
pacman -Q openssh wpa_supplicant dhcpcd

# Check services
systemctl status sshd
systemctl status wpa_supplicant@wlan0

# Check disk usage
df -h

# Check memory
free -h

# Check network
ip addr show wlan0
```

## Testing Checklist

- [ ] Image flashes successfully
- [ ] WiFi config file created on boot partition
- [ ] Device boots (LED activity visible)
- [ ] Device connects to WiFi (visible on router)
- [ ] SSH connection works
- [ ] `openssh` package installed
- [ ] `wpa_supplicant` installed
- [ ] `sshd` service running
- [ ] Root partition resized to full SD card
- [ ] Root password is `orangepi`
- [ ] Hostname is `orangepi-zero2w`

## Troubleshooting

### WiFi not connecting
1. Check wifi.conf format (no extra spaces, correct quotes)
2. Check SSID and password are correct
3. Check first boot completed: `ls /var/lib/firstboot-done`
4. Check WiFi logs: `journalctl -u wpa_supplicant@wlan0`

### SSH not working
1. Check if first boot completed (packages need to install)
2. Check sshd running: `systemctl status sshd`
3. Try connecting via HDMI console first
4. Check if openssh installed: `pacman -Q openssh`

### Can't find device IP
1. Connect HDMI monitor and USB keyboard
2. Login at console: `root` / `orangepi`
3. Check IP: `ip addr show wlan0`
4. Check WiFi status: `systemctl status wpa_supplicant@wlan0`

### First boot taking too long
- First boot installs packages from internet (~2-5 minutes)
- Check LED activity - should be blinking
- Wait up to 5 minutes before investigating

## USB Gadget Network Mode (Alternative)

If WiFi doesn't work, you can use USB networking:

1. After flashing, mount boot partition
2. Create file `gadget-mode`:
   ```bash
   echo "network" > /Volumes/BOOT/gadget-mode
   ```
3. Boot Orange Pi
4. Connect USB-C cable to computer
5. SSH to `192.168.7.2`

## Expected First Boot Timeline

```
[0s]    Power on
[5s]    Kernel loading
[10s]   Systemd init
[15s]   firstboot.service starts
[20s]   WiFi configuration
[25s]   Connecting to WiFi
[30s]   Installing packages (pacman -Sy)
[90s]   Installing openssh, wpa_supplicant, etc.
[120s]  Generating SSH keys
[125s]  SSH ready!
```

## Test Results Template

Copy this to document your test:

```
Date: YYYY-MM-DD
Image: orangepi-zero2w-runtime (Build #XXXXX, Commit: xxxxxxx)
Hardware: Orange Pi Zero 2W (RAM: 1GB/2GB/4GB)
SD Card: Brand/Size

[ ] Image flashed successfully
[ ] WiFi configured
[ ] Device booted
[ ] WiFi connected (IP: xxx.xxx.xxx.xxx)
[ ] SSH accessible
[ ] Packages installed: openssh, wpa_supplicant, dhcpcd
[ ] Services running: sshd, wpa_supplicant@wlan0, dhcpcd@wlan0
[ ] Disk space: X MB used / Y MB total
[ ] Memory: X MB used / Y MB available

Notes:
-
```

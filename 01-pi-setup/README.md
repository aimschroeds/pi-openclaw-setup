# Raspberry Pi Headless Setup (CLI Only)

Set up and use your Raspberry Pi without a monitor — entirely from the command line.

## What You Need

### Hardware

| Item | Notes |
|---|---|
| Raspberry Pi | Any model with networking (Wi-Fi or Ethernet) |
| microSD card | 16 GB minimum, 32 GB recommended. Class 10 / A1 or faster |
| microSD card reader | USB adapter or built-in laptop slot. A microSD-to-SD adapter (often included with the card) works for full-size SD slots |
| USB-C power supply | 5V/3A for Pi 4 and 5. Older models use micro-USB (5V/2.5A). Using an underpowered supply causes random crashes and Wi-Fi drops |
| Ethernet cable (optional) | Simplifies setup — skip the Wi-Fi config step entirely |

### On Your Computer

- Another computer on the same network (Linux or macOS; Windows works but commands differ)
- `curl` and `xz` for downloading/extracting the image
- `dd` for flashing (pre-installed on Linux/macOS)
- `openssl` for generating the password hash (pre-installed on most systems)
- `nmap` or `arp-scan` (optional, for finding the Pi on your network)

## Step 1: Download the OS Image

```bash
# Find the latest Raspberry Pi OS Lite image URL
# https://www.raspberrypi.com/software/operating-systems/

# Download (example — check site for current URL)
curl -L -o raspios.img.xz https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64-lite.img.xz

# Extract
xz -d raspios.img.xz
```

## Step 2: Flash the SD Card

```bash
# Find your SD card device
lsblk                          # Linux
diskutil list                  # macOS

# ⚠️  Double-check the device name — writing to the wrong disk will destroy data

# Unmount the SD card
sudo umount /dev/sdX*          # Linux (replace sdX with your device)
diskutil unmountDisk /dev/diskN # macOS (replace diskN with your device)

# Write the image
sudo dd if=raspios.img of=/dev/sdX bs=4M status=progress  # Linux
sudo dd if=raspios.img of=/dev/rdiskN bs=4m               # macOS (rdisk is faster)

# Flush writes
sync
```

## Step 3: Configure the Boot Partition

After flashing, mount the boot partition of the SD card. It usually auto-mounts
as `bootfs`.

```bash
# Find where it mounted
lsblk       # Linux — look for the smaller partition (usually ~512 MB)
# Typically: /media/$USER/bootfs (Linux) or /Volumes/bootfs (macOS)

BOOT=/media/$USER/bootfs       # Linux — adjust if needed
# BOOT=/Volumes/bootfs         # macOS
```

### Enable SSH

```bash
touch "$BOOT/ssh"
```

### Set Username and Password

```bash
# Generate an encrypted password
PASSWORD=$(echo 'YOUR_PASSWORD_HERE' | openssl passwd -6 -stdin)

# Write the user config (replace 'pi' with your preferred username)
echo "pi:$PASSWORD" > "$BOOT/userconf.txt"
```

### Configure Wi-Fi

```bash
cat > "$BOOT/wpa_supplicant.conf" << 'EOF'
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="YOUR_WIFI_NAME"
    psk="YOUR_WIFI_PASSWORD"
    key_mgmt=WPA-PSK
}
EOF
```

> Replace `US` with your country code, and fill in your Wi-Fi SSID and password.

### Unmount

```bash
sudo umount "$BOOT"
# macOS: diskutil unmountDisk /dev/diskN
```

## Step 4: Boot and Find the Pi

Insert the SD card, power on the Pi, and wait ~60–90 seconds.

```bash
# Option 1: mDNS (if avahi/bonjour is available)
ping -c 3 raspberrypi.local

# Option 2: Scan your local network (requires nmap)
nmap -sn 192.168.1.0/24

# Option 3: Check your router's DHCP lease table
# (varies by router — usually accessible at 192.168.1.1 in a browser)

# Option 4: ARP scan (requires arp-scan)
sudo arp-scan --localnet
```

## Step 5: Connect via SSH

```bash
ssh pi@raspberrypi.local
# Or use the IP address you found:
# ssh pi@192.168.1.XXX
```

Accept the host key fingerprint on first connection, then enter your password.

## Step 6: Initial Setup on the Pi

Once connected, run these to get your Pi up to date:

```bash
# Update packages
sudo apt update && sudo apt full-upgrade -y

# Set timezone
sudo timedatectl set-timezone America/Los_Angeles   # adjust to your timezone

# Set hostname (optional)
sudo hostnamectl set-hostname mypi
```

## SSH Key Setup (Skip the Password)

On your local machine:

```bash
# Generate a key if you don't have one
ssh-keygen -t ed25519

# Copy it to the Pi
ssh-copy-id pi@raspberrypi.local
```

Now `ssh pi@raspberrypi.local` connects without a password prompt.

## Useful Commands

```bash
# System info
cat /proc/device-tree/model        # Pi model
cat /etc/os-release                # OS version
vcgencmd measure_temp              # CPU temperature
free -h                            # Memory usage
df -h                              # Disk usage

# Networking
hostname -I                        # IP address
iwconfig                           # Wi-Fi status
nmcli dev wifi list                # Available Wi-Fi networks (bookworm+)

# Power
sudo shutdown -h now               # Shut down
sudo reboot                        # Reboot
```

## Troubleshooting

| Problem | Fix |
|---|---|
| Can't find Pi on network | Double-check Wi-Fi creds in `wpa_supplicant.conf`; try Ethernet instead |
| `Connection refused` on port 22 | The `ssh` file is missing from boot partition — re-mount and add it |
| `raspberrypi.local` doesn't resolve | Use IP instead; install avahi on Pi later: `sudo apt install avahi-daemon` |
| `Permission denied` | Check username in `userconf.txt`; try: `ssh -o PreferredAuthentications=password pi@host` |
| Wi-Fi connects then drops | Check power supply — undervoltage causes Wi-Fi instability |

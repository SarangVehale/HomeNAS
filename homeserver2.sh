#!/bin/bash

set -e

# === Load configuration ===
if [ -f "./config.env" ]; then
    source ./config.env
else
    echo "Missing config.env file. Please create one with your DUCKDNS_TOKEN and DUCKDNS_DOMAIN."
    exit 1
fi

# === Function to handle errors ===
error_exit() {
    echo "❌ Error: $1"
    echo "Exiting script."
    exit 1
}

echo "=== 🚀 Setting Up Hybrid NAS + Workstation System ==="

# === CONFIGURABLES ===
MOUNT_POINT="/mnt/nasdrive"
NEXTCLOUD_DATA="$MOUNT_POINT/nextcloud-data"
TOR_SERVICE_DIR="/var/lib/tor/nextcloud_hidden"
DEFAULT_USERNAME=$SUDO_USER
DISK_LABEL="nasdrive"

# === 1. System Update and Install Packages ===
echo "[1/15] Updating system..."
sudo apt update || error_exit "Failed to update package list."
sudo apt upgrade -y || error_exit "Failed to upgrade packages."

echo "[2/15] Installing required packages..."
sudo apt install -y \
    curl tor ufw samba syncthing \
    software-properties-common fail2ban \
    unattended-upgrades wget jq net-tools \
    cockpit wireguard resolvconf \
    snapd nginx certbot python3-certbot-nginx \
    || error_exit "Package installation failed."

# === 2. Syncthing as user service ===
echo "[2.1] Enabling Syncthing user service..."
sudo loginctl enable-linger "$DEFAULT_USERNAME" || error_exit "Failed to enable linger for user."
sudo -u "$DEFAULT_USERNAME" bash -c '
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
    systemctl --user enable syncthing.service
    systemctl --user start syncthing.service
' || error_exit "Failed to enable/start Syncthing as user service."

# === 3. Unattended upgrades ===
echo "[3/15] Configuring automatic updates..."
sudo dpkg-reconfigure --priority=low unattended-upgrades || error_exit "Unattended upgrades failed."

# === 4. Fail2Ban ===
echo "[4/15] Enabling Fail2Ban..."
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# === 5. Firewall Configuration ===
echo "[5/15] Configuring UFW firewall..."
sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 32400    # Jellyfin
sudo ufw allow 8384     # Syncthing
sudo ufw allow 9090     # Cockpit
sudo ufw allow 51820/udp # WireGuard VPN
sudo ufw --force enable

# === 6. Mount External Drive ===
echo "[6/15] Mounting external drive..."
DISK=$(lsblk -rpno NAME,TYPE | grep 'part' | grep -v "/$" | head -n1 | cut -d' ' -f1) || error_exit "No disk found."
UUID=$(sudo blkid -s UUID -o value "$DISK") || error_exit "Failed to get disk UUID."

sudo mkdir -p "$MOUNT_POINT"
grep -q "$UUID" /etc/fstab || echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" | sudo tee -a /etc/fstab
sudo mount -a || error_exit "Failed to mount external drive."

# === 7. Nextcloud via Snap ===
echo "[7/15] Installing Nextcloud..."
sudo snap install nextcloud || error_exit "Nextcloud install failed."
sudo snap stop nextcloud

echo "[7.1] Relocating Nextcloud data..."
sudo mv /var/snap/nextcloud/common/nextcloud/data "$NEXTCLOUD_DATA" || error_exit "Failed to move data."
sudo ln -s "$NEXTCLOUD_DATA" /var/snap/nextcloud/common/nextcloud/data
sudo snap start nextcloud

# === 8. Tor Hidden Service ===
echo "[8/15] Setting up Tor hidden service..."
if ! grep -q "$TOR_SERVICE_DIR" /etc/tor/torrc; then
    echo "
HiddenServiceDir $TOR_SERVICE_DIR
HiddenServicePort 80 127.0.0.1:80
" | sudo tee -a /etc/tor/torrc
fi
sudo systemctl restart tor

# === 9. Jellyfin ===
echo "[9/15] Installing Jellyfin..."
wget -O - https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/jellyfin.gpg
echo "deb [signed-by=/usr/share/keyrings/jellyfin.gpg] https://repo.jellyfin.org/ubuntu $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list
sudo apt update
sudo apt install -y jellyfin
sudo systemctl enable jellyfin
sudo systemctl start jellyfin

# === 10. Samba File Share ===
echo "[10/15] Configuring Samba share..."
sudo tee -a /etc/samba/smb.conf > /dev/null <<EOF

[$DISK_LABEL]
   path = $MOUNT_POINT
   browseable = yes
   read only = no
   guest ok = yes
   force user = $DEFAULT_USERNAME
EOF
sudo systemctl restart smbd

# === 11. Set Permissions ===
echo "[11/15] Setting permissions..."
sudo chown -R "$DEFAULT_USERNAME:$DEFAULT_USERNAME" "$MOUNT_POINT"

# === 12. DuckDNS Dynamic DNS ===
echo "[12/15] Configuring DuckDNS..."
if [[ -z "$DUCKDNS_TOKEN" || -z "$DUCKDNS_DOMAIN" ]]; then
    echo "Skipping DuckDNS – token/domain missing."
else
    echo "*/5 * * * * root curl -s 'https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip='" | sudo tee /etc/cron.d/duckdns
fi

# === 13. Let's Encrypt SSL ===
echo "[13/15] SSL with Let's Encrypt..."
if [[ -n "$DUCKDNS_DOMAIN" ]]; then
    sudo systemctl enable nginx
    sudo systemctl start nginx
    sudo certbot --nginx -d "$DUCKDNS_DOMAIN" || echo "SSL failed – check logs manually."
else
    echo "Skipping SSL – domain not configured."
fi

# === 14. Cockpit Web Admin ===
echo "[14/15] Enabling Cockpit Web Dashboard..."
sudo systemctl enable cockpit.socket
sudo systemctl start cockpit.socket

# === 15. WireGuard VPN ===
echo "[15/15] Setting up WireGuard VPN..."
if [ ! -f "/etc/wireguard/wg0.conf" ]; then
    sudo wg genkey | tee privatekey | wg pubkey > publickey
    PRIVATE_KEY=$(cat privatekey)
    sudo tee /etc/wireguard/wg0.conf > /dev/null <<EOF
[Interface]
Address = 10.0.0.1/24
SaveConfig = true
PrivateKey = $PRIVATE_KEY
ListenPort = 51820
EOF
    sudo systemctl enable wg-quick@wg0
    sudo systemctl start wg-quick@wg0
    rm privatekey publickey
fi

# === Summary ===
ONION=$(sudo cat "$TOR_SERVICE_DIR/hostname" 2>/dev/null || echo "Unavailable")

echo "========================================"
echo "🎉 Setup complete!"
echo "• Nextcloud: http://localhost or .onion: $ONION"
echo "• Samba: \\\\$HOSTNAME\\$DISK_LABEL"
echo "• Syncthing: http://localhost:8384"
echo "• Jellyfin: http://localhost:8096"
echo "• Cockpit: https://localhost:9090"
echo "• VPN (WireGuard): Server running on port 51820"
echo "• External Storage: $MOUNT_POINT"
echo "• Dynamic DNS: $DUCKDNS_DOMAIN"
echo "• SSL: https://$DUCKDNS_DOMAIN (if configured)"
echo "========================================"


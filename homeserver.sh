#!/bin/bash

set -e

# Function to handle errors
error_exit() {
    echo "Error: $1"
    echo "Exiting script."
    exit 1
}

echo "=== 🚀 Setting Up Hybrid NAS + Workstation System ==="

#--- CONFIGURABLES ---
MOUNT_POINT="/mnt/nasdrive"
NEXTCLOUD_DATA="$MOUNT_POINT/nextcloud-data"
TOR_SERVICE_DIR="/var/lib/tor/nextcloud_hidden"
DEFAULT_USERNAME=$SUDO_USER
DISK_LABEL="nasdrive"  # Default disk label for mounting

#--- 1. Update system and install packages ---
echo "[1/13] Updating system packages..."
sudo apt update || error_exit "Failed to update package list."
sudo apt upgrade -y || error_exit "Failed to upgrade system packages."

echo "[2/13] Installing required packages..."
sudo apt install -y curl tor ufw samba syncthing software-properties-common fail2ban unattended-upgrades wget jq || error_exit "Failed to install required packages."

# Enable Syncthing for the main user
echo "[2.1] Enabling Syncthing user service..."

sudo -u "$DEFAULT_USERNAME" bash -c '
    systemctl --user enable syncthing.service || exit 1
    systemctl --user start syncthing.service || exit 1
' || error_exit "Failed to enable/start Syncthing as a user service."


#--- 2. Configure Unattended Upgrades ---
echo "[3/13] Setting up automatic security updates..."
sudo dpkg-reconfigure --priority=low unattended-upgrades || error_exit "Failed to configure unattended upgrades."

#--- 3. Enable Fail2Ban ---
echo "[4/13] Enabling Fail2Ban for brute-force protection..."
sudo systemctl enable fail2ban || error_exit "Failed to enable Fail2Ban service."
sudo systemctl start fail2ban || error_exit "Failed to start Fail2Ban service."

#--- 4. Set up firewall ---
echo "[5/13] Configuring firewall..."
sudo ufw allow 22     || error_exit "Failed to allow SSH in firewall."
sudo ufw allow 80     || error_exit "Failed to allow HTTP in firewall."
sudo ufw allow 443    || error_exit "Failed to allow HTTPS in firewall."
sudo ufw allow 32400  || error_exit "Failed to allow Jellyfin in firewall."
sudo ufw allow 8384   || error_exit "Failed to allow Syncthing in firewall."
sudo ufw enable || error_exit "Failed to enable firewall."

#--- 5. Mount External Drive ---
echo "[6/13] Mounting external drive..."
DISK=$(lsblk -rpno NAME,TYPE | grep 'part' | grep -v "/$" | head -n1 | cut -d' ' -f1) || error_exit "Failed to detect disk."
UUID=$(sudo blkid -s UUID -o value "$DISK") || error_exit "Failed to get UUID of the disk."

if [ -z "$UUID" ]; then
    error_exit "Disk UUID is empty. Check if the disk is connected."
fi

sudo mkdir -p "$MOUNT_POINT" || error_exit "Failed to create mount point."
grep -q "$UUID" /etc/fstab || echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" | sudo tee -a /etc/fstab || error_exit "Failed to add mount entry in fstab."
sudo mount -a || error_exit "Failed to mount the external drive."

#--- 6. Install Nextcloud via Snap ---
echo "[7/13] Installing Nextcloud..."
sudo snap install nextcloud || error_exit "Failed to install Nextcloud via Snap."
sudo snap stop nextcloud || error_exit "Failed to stop Nextcloud service."

# Move Nextcloud data directory
echo "[7.1] Moving Nextcloud data directory..."
sudo mv /var/snap/nextcloud/common/nextcloud/data "$NEXTCLOUD_DATA" || error_exit "Failed to move Nextcloud data directory."
sudo ln -s "$NEXTCLOUD_DATA" /var/snap/nextcloud/common/nextcloud/data || error_exit "Failed to create symbolic link for Nextcloud data."
sudo snap start nextcloud || error_exit "Failed to start Nextcloud service."

#--- 7. Set up Tor Hidden Service for Nextcloud ---
echo "[8/13] Configuring Tor hidden service..."
if ! grep -q "$TOR_SERVICE_DIR" /etc/tor/torrc; then
    echo "
HiddenServiceDir $TOR_SERVICE_DIR
HiddenServicePort 80 127.0.0.1:80
" | sudo tee -a /etc/tor/torrc || error_exit "Failed to add Tor hidden service configuration."
fi
sudo systemctl restart tor || error_exit "Failed to restart Tor service."

#--- 8. Install Jellyfin (media server) ---
echo "[9/13] Installing Jellyfin media server..."
wget -O - https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/jellyfin.gpg || error_exit "Failed to download Jellyfin GPG key."
echo "deb [signed-by=/usr/share/keyrings/jellyfin.gpg] https://repo.jellyfin.org/ubuntu $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list || error_exit "Failed to add Jellyfin repository."
sudo apt update || error_exit "Failed to update package list after adding Jellyfin repo."
sudo apt install -y jellyfin || error_exit "Failed to install Jellyfin."
sudo systemctl enable jellyfin || error_exit "Failed to enable Jellyfin service."
sudo systemctl start jellyfin || error_exit "Failed to start Jellyfin service."

#--- 9. Set up Samba for LAN file sharing ---
echo "[10/13] Configuring Samba..."
sudo tee -a /etc/samba/smb.conf > /dev/null <<EOF

[$DISK_LABEL]
   comment = External Drive Share
   path = $MOUNT_POINT
   browseable = yes
   read only = no
   guest ok = yes
   force user = $DEFAULT_USERNAME
EOF
sudo systemctl restart smbd || error_exit "Failed to restart Samba service."

#--- 10. Set file permissions for NAS mount ---
echo "[11/13] Setting permissions on $MOUNT_POINT..."
sudo chown -R $DEFAULT_USERNAME:$DEFAULT_USERNAME "$MOUNT_POINT" || error_exit "Failed to change ownership of mount directory."

#--- 11. Optional Dynamic DNS (via DuckDNS) ---
echo "[12/13] Setting up Dynamic DNS (DuckDNS)..."
DUCKDNS_TOKEN="<your_duckdns_token>"
DUCKDNS_DOMAIN="<your_duckdns_domain>"
if [ -z "$DUCKDNS_TOKEN" ] || [ -z "$DUCKDNS_DOMAIN" ]; then
    echo "Skipping Dynamic DNS setup. Please configure your DuckDNS details."
else
    echo "Creating DuckDNS cron job for dynamic IP update..."
    echo "*/5 * * * * curl -s https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip=" | sudo tee -a /etc/crontab || error_exit "Failed to add DuckDNS cron job."
fi

#--- 12. Enable SSL with Let's Encrypt (Optional) ---
echo "[13/13] Setting up SSL with Let's Encrypt (Optional)..."
if [ -z "$DUCKDNS_DOMAIN" ]; then
    echo "Skipping SSL setup due to missing DuckDNS domain."
else
    sudo apt install -y certbot python3-certbot-nginx || error_exit "Failed to install Certbot."
    sudo systemctl enable nginx || error_exit "Failed to enable Nginx."
    sudo systemctl start nginx || error_exit "Failed to start Nginx."

    echo "[13.1] Acquiring SSL certificate..."
    sudo certbot --nginx -d $DUCKDNS_DOMAIN || error_exit "Failed to acquire SSL certificate from Let's Encrypt."
fi

#--- 13. Display Setup Summary ---
ONION=$(sudo cat "$TOR_SERVICE_DIR/hostname" 2>/dev/null || echo "Not available yet (wait ~60 seconds)")

echo "======================================"
echo "🎉 Setup complete!"
echo "• Nextcloud: http://localhost or via Tor: $ONION"
echo "• Samba (LAN): \\\\$HOSTNAME\\nasdrive"
echo "• Syncthing: http://localhost:8384"
echo "• Jellyfin (Media Server): http://localhost:8096"
echo "• External storage mounted at: $MOUNT_POINT"
echo "• Dynamic DNS: $DUCKDNS_DOMAIN (if configured)"
echo "• SSL: https://$DUCKDNS_DOMAIN (if configured)"
echo "======================================"

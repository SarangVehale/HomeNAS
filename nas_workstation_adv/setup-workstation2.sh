#!/bin/bash

set -e

#=====================================
# 🚀 Hybrid NAS + Workstation Setup
#=====================================
# Requirements: Debian/Ubuntu based system
# External config: config.env (must be present in same directory)
#=====================================

# Load configuration from external file
if [[ ! -f ./config.env ]]; then
    echo "Missing config.env. Please create it with your credentials and tokens."
    exit 1
fi
source ./config.env

# Function to handle errors
error_exit() {
    echo "Error: $1"
    echo "Exiting script."
    exit 1
}

#--- VARIABLES ---
MOUNT_POINT="/mnt/nasdrive"
NEXTCLOUD_DATA="$MOUNT_POINT/nextcloud-data"
TOR_SERVICE_DIR="/var/lib/tor/nextcloud_hidden"
DEFAULT_USERNAME=$SUDO_USER
DISK_LABEL="nasdrive"

#--- 1. System Update and Package Installation ---
echo "[1/15] Updating and installing required packages..."
sudo apt update && sudo apt upgrade -y || error_exit "Failed to update system."
sudo apt install -y \
    curl tor ufw samba syncthing software-properties-common fail2ban unattended-upgrades \
    wget jq docker.io docker-compose ttyd nginx certbot python3-certbot-nginx \
    git build-essential libssl-dev libffi-dev python3-dev python3-pip \
    sqlite3 acl net-tools || error_exit "Failed to install packages."

#--- 2. Enable Syncthing ---
echo "[2/15] Enabling Syncthing..."
sudo -u "$DEFAULT_USERNAME" bash -c '
    export XDG_RUNTIME_DIR="/run/user/$(id -u $USER)"
    systemctl --user enable syncthing.service || exit 1
    systemctl --user start syncthing.service || exit 1
' || echo "Warning: Could not start Syncthing user service."

#--- 3. Security Updates & Fail2Ban ---
echo "[3/15] Configuring security..."
sudo dpkg-reconfigure --priority=low unattended-upgrades || error_exit "Unattended upgrades failed."
sudo systemctl enable fail2ban && sudo systemctl start fail2ban || error_exit "Fail2Ban failed."

#--- 4. Configure Firewall ---
echo "[4/15] Setting up UFW..."
sudo ufw allow 22 80 443 32400 8384 8096 3000 3001 8080 7681 5173 || error_exit "UFW rule error."
sudo ufw enable || error_exit "Failed to enable firewall."

#--- 5. Mount External Drive ---
echo "[5/15] Mounting disk..."
DISK=$(lsblk -rpno NAME,TYPE | grep 'part' | grep -v "/$" | head -n1 | cut -d' ' -f1)
UUID=$(sudo blkid -s UUID -o value "$DISK")
[ -z "$UUID" ] && error_exit "No UUID found."
sudo mkdir -p "$MOUNT_POINT"
grep -q "$UUID" /etc/fstab || echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" | sudo tee -a /etc/fstab
sudo mount -a || error_exit "Failed mounting disk."
sudo chown -R $DEFAULT_USERNAME:$DEFAULT_USERNAME "$MOUNT_POINT"

#--- 6. Nextcloud Installation ---
echo "[6/15] Installing Nextcloud..."
sudo snap install nextcloud || error_exit "Snap install failed."
sudo snap stop nextcloud
sudo mv /var/snap/nextcloud/common/nextcloud/data "$NEXTCLOUD_DATA"
sudo ln -s "$NEXTCLOUD_DATA" /var/snap/nextcloud/common/nextcloud/data
sudo snap start nextcloud || error_exit "Nextcloud start failed."

#--- 7. Tor Hidden Service ---
echo "[7/15] Setting up Tor hidden service..."
echo -e "\nHiddenServiceDir $TOR_SERVICE_DIR\nHiddenServicePort 80 127.0.0.1:80" | sudo tee -a /etc/tor/torrc
sudo systemctl restart tor

#--- 8. Jellyfin ---
echo "[8/15] Installing Jellyfin..."
wget -O - https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/jellyfin.gpg
echo "deb [signed-by=/usr/share/keyrings/jellyfin.gpg] https://repo.jellyfin.org/ubuntu $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list
sudo apt update && sudo apt install -y jellyfin || error_exit "Jellyfin install failed."
sudo systemctl enable jellyfin && sudo systemctl start jellyfin

#--- 9. Samba ---
echo "[9/15] Setting up Samba..."
sudo tee -a /etc/samba/smb.conf > /dev/null <<EOF
[$DISK_LABEL]
   path = $MOUNT_POINT
   browseable = yes
   read only = no
   guest ok = yes
   force user = $DEFAULT_USERNAME
EOF
sudo systemctl restart smbd

#--- 10. DuckDNS ---
echo "[10/15] Configuring DuckDNS..."
if [[ -n "$DUCKDNS_TOKEN" && -n "$DUCKDNS_DOMAIN" ]]; then
    echo "*/5 * * * * root curl -s \"https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip=\"" | sudo tee /etc/cron.d/duckdns
else
    echo "DuckDNS not configured."
fi

#--- 11. Let's Encrypt SSL ---
echo "[11/15] Configuring SSL..."
if [[ -n "$DUCKDNS_DOMAIN" ]]; then
    sudo certbot --nginx -d "$DUCKDNS_DOMAIN" || echo "SSL cert failed."
fi

#--- 12. AdGuard Home ---
echo "[12/15] Installing AdGuard Home..."
AGH_URL="https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz"
wget "$AGH_URL" -O AdGuardHome.tar.gz
tar -xzf AdGuardHome.tar.gz
cd AdGuardHome && sudo ./AdGuardHome -s install
cd ..

#--- 13. Code Server (VS Code in browser) ---
echo "[13/15] Installing Code Server..."
wget https://github.com/coder/code-server/releases/download/v4.23.1/code-server_4.23.1_amd64.deb
sudo dpkg -i code-server_4.23.1_amd64.deb || sudo apt --fix-broken install -y
sudo systemctl enable --now code-server@$DEFAULT_USERNAME

#--- 14. SSH Web Terminal (ttyd) ---
echo "[14/15] Starting ttyd SSH web terminal..."
sudo nohup ttyd -p 7681 login &

#--- 15. Homer Dashboard (User Portal) ---
echo "[15/15] Setting up Homer Dashboard..."
sudo git clone https://github.com/bastienwirtz/homer /opt/homer
cd /opt/homer
sudo docker compose up -d

#--- Add Homer Auto-Update Cron Job ---
echo "Creating auto-update for Homer dashboard config..."
sudo tee /usr/local/bin/update-homer-config.sh > /dev/null << 'EOC'
#!/bin/bash
cd /opt/homer && git pull && docker compose restart
EOC
sudo chmod +x /usr/local/bin/update-homer-config.sh
echo "*/30 * * * * root /usr/local/bin/update-homer-config.sh" | sudo tee /etc/cron.d/homer-auto-update

#--- DONE ---
ONION=$(sudo cat "$TOR_SERVICE_DIR/hostname" 2>/dev/null || echo "Not available yet")
echo "======================================"
echo "🎉 Setup complete!"
echo "• Nextcloud: http://localhost or via Tor: $ONION"
echo "• Samba: \\$HOSTNAME\\nasdrive"
echo "• Syncthing: http://localhost:8384"
echo "• Jellyfin: http://localhost:8096"
echo "• AdGuard: http://localhost:3000"
echo "• Code Server: http://localhost:8080"
echo "• SSH Web Terminal: http://localhost:7681"
echo "• Dashboard: http://localhost:5173"
echo "• DuckDNS: https://$DUCKDNS_DOMAIN (if set)"
echo "======================================"


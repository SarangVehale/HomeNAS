#!/bin/bash
set -euo pipefail

CONFIG_FILE="./config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file $CONFIG_FILE not found! Please place config.env in the same folder as this script."
    exit 1
fi
source "$CONFIG_FILE"

cat <<EOF
===========================================================
🧹 Hybrid NAS + Workstation Interactive Uninstallation Assistant
-----------------------------------------------------------
Usage:

    Make executable:
        chmod +x uninstall-hybrid-nas-workstation.sh

    Run as root:
        sudo ./uninstall-hybrid-nas-workstation.sh

Follow the prompts to confirm each action.

This script helps safely:

    • Stop & disable all installed services
    • Remove installed packages & snaps
    • Delete Samba & system users created (except your default user)
    • Reset firewall rules to safe defaults
    • Remove mounts & fstab entries
    • Remove Tor hidden service configs
    • Remove Restic backups & cron jobs
    • Remove DuckDNS cron jobs
    • Remove Nextcloud, Jellyfin, Syncthing, Samba, Tor, Wireguard, Fail2Ban configs & data
    • Remove logs and temporary files

NOTE:
    • It WON'T delete personal data outside your NAS mount point or home directories.
    • Double-check user removals carefully.
    • Manual cleanup might still be needed depending on your usage.
===========================================================
EOF

confirm() {
    read -r -p "$1 [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) true ;;
        *) false ;;
    esac
}

if ! confirm "Continue with uninstallation? This action is irreversible."; then
    echo "Aborted."
    exit 0
fi

stop_disable_services() {
    echo "[1] Stop and disable services..."
    local services=(
        jellyfin
        syncthing@"$DEFAULT_USERNAME"
        tor
        cockpit
        fail2ban
        smartd
        netdata
        nginx
        unattended-upgrades
    )
    if [[ "${WG_ENABLED:-false}" == true ]]; then
        services+=( "wg-quick@${WG_INTERFACE}" )
    fi
    for svc in "${services[@]}"; do
        echo "Stopping and disabling $svc..."
        sudo systemctl stop "$svc" || true
        sudo systemctl disable "$svc" || true
    done

    for user in $(echo "${USERS:-}" | tr ',' ' '); do
        echo "Stopping and disabling syncthing for user $user..."
        sudo systemctl stop syncthing@"$user" || true
        sudo systemctl disable syncthing@"$user" || true
    done
}

remove_packages() {
    echo "[2] Remove installed packages and snaps..."
    sudo apt-get purge -y jellyfin syncthing tor fail2ban cockpit netdata wireguard wireguard-tools zram-config nginx \
        unattended-upgrades certbot python3-certbot-nginx samba smartmontools restic qrencode || true
    sudo apt-get autoremove -y
    sudo snap remove nextcloud || true
}

remove_samba_users() {
    echo "[3] Remove Samba users..."
    for user in "$DEFAULT_USERNAME" $(echo "${USERS:-}" | tr ',' ' '); do
        echo "Removing Samba user $user..."
        sudo smbpasswd -x "$user" || true
    done
}

remove_system_users() {
    echo "[4] Remove system users (except default user '$DEFAULT_USERNAME')..."
    for user in $(echo "${USERS:-}" | tr ',' ' '); do
        if id -u "$user" >/dev/null 2>&1; then
            echo "Deleting system user $user and their home directory..."
            sudo deluser --remove-home "$user" || true
        fi
    done
}

reset_firewall() {
    echo "[5] Reset firewall rules (UFW)..."
    sudo ufw reset -y
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow "$PORT_SSH"
    sudo ufw --force enable
}

remove_mounts() {
    echo "[6] Remove mount from fstab and unmount NAS drive..."
    UUID=$(sudo blkid -s UUID -o value "$(lsblk -rpno NAME,TYPE | grep 'part' | grep -v "/$" | head -n1)" || true)
    if [[ -n "$UUID" ]]; then
        echo "Removing fstab entry for UUID=$UUID..."
        sudo sed -i "\|UUID=$UUID|d" /etc/fstab || true
    fi
    echo "Unmounting $MOUNT_POINT..."
    sudo umount "$MOUNT_POINT" || true
    echo "Removing mount directory $MOUNT_POINT..."
    sudo rm -rf "$MOUNT_POINT"
}

remove_tor_config() {
    echo "[7] Remove Tor hidden service directory and config..."
    sudo rm -rf "$TOR_SERVICE_DIR"
    sudo sed -i "\|$TOR_SERVICE_DIR|d" /etc/tor/torrc || true
    sudo systemctl restart tor || true
}

remove_restic_cron() {
    echo "[8] Remove Restic backup repository and cron jobs..."
    sudo rm -rf "$RESTIC_REPO"
    sudo crontab -l 2>/dev/null | grep -v restic | sudo crontab -
}

remove_duckdns_cron() {
    echo "[9] Remove DuckDNS cron job..."
    sudo crontab -l 2>/dev/null | grep -v duckdns.org/update | sudo crontab -
}

remove_configs_and_data() {
    echo "[10] Remove Nextcloud, Jellyfin, Syncthing, Samba, Tor, Wireguard, Fail2Ban configs and data..."

    sudo rm -rf /var/snap/nextcloud
    sudo rm -rf /etc/jellyfin /var/lib/jellyfin /var/log/jellyfin

    sudo rm -rf /home/"$DEFAULT_USERNAME"/.config/syncthing
    for user in $(echo "${USERS:-}" | tr ',' ' '); do
        sudo rm -rf /home/"$user"/.config/syncthing
    done

    sudo sed -i "\|$DISK_LABEL|d" /etc/samba/smb.conf
    sudo systemctl restart smbd || true

    sudo rm -rf /var/lib/tor
    if [[ "${WG_ENABLED:-false}" == true ]]; then
        sudo rm -rf /etc/wireguard
    fi

    sudo rm -rf /etc/fail2ban
}

remove_logs() {
    echo "[11] Remove logs and temp files..."

    local log_dirs=(
        /var/log/jellyfin
        /var/log/syncthing
        /var/log/tor
        /var/log/fail2ban
        /var/log/nginx
        /var/log/cockpit
    )

    for d in "${log_dirs[@]}"; do
        sudo rm -rf "$d" || true
    done
}

remove_cockpit_netdata_zram() {
    echo "[12] Remove Cockpit configs..."
    sudo rm -rf /etc/cockpit /var/lib/cockpit

    echo "[13] Remove Netdata configs and data..."
    sudo rm -rf /etc/netdata /var/lib/netdata /var/cache/netdata /var/log/netdata

    echo "[14] Remove ZRAM config..."
    sudo rm -rf /etc/default/zram-config /etc/systemd/system/zram-config.service.d
}

final_message() {
    echo "[15] Final cleanup complete!"
    echo "======================================"
    echo "🧹 Uninstallation complete!"
    echo "Please verify manually if any personal data remains and clean as necessary."
    echo "You may want to check:"
    echo "  - Your home directories for leftover configs (e.g., ~/.config/nextcloud)"
    echo "  - Any custom mounts or backups outside this setup"
    echo "  - Your NAS drive contents if you want to clear data"
    echo "  - Logs or caches in /tmp or /var/tmp"
    echo "======================================"
}

# Run steps interactively
if confirm "Stop and disable all services?"; then
    stop_disable_services
fi

if confirm "Remove installed packages and snaps?"; then
    remove_packages
fi

if confirm "Remove Samba users?"; then
    remove_samba_users
fi

if confirm "Remove system users (except default user '$DEFAULT_USERNAME')?"; then
    remove_system_users
fi

if confirm "Reset firewall rules to safe defaults?"; then
    reset_firewall
fi

if confirm "Remove mounts and fstab entries?"; then
    remove_mounts
fi

if confirm "Remove Tor hidden service configuration?"; then
    remove_tor_config
fi

if confirm "Remove Restic backups and cron jobs?"; then
    remove_restic_cron
fi

if confirm "Remove DuckDNS cron jobs?"; then
    remove_duckdns_cron
fi

if confirm "Remove Nextcloud, Jellyfin, Syncthing, Samba, Tor, Wireguard, Fail2Ban configs and data?"; then
    remove_configs_and_data
fi

if confirm "Remove logs and temporary files?"; then
    remove_logs
fi

if confirm "Remove Cockpit, Netdata, and ZRAM configs and data?"; then
    remove_cockpit_netdata_zram
fi

final_message


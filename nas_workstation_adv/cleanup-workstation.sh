#!/bin/bash
set -euo pipefail

CONFIG_FILE="./config.env"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config file $CONFIG_FILE not found! Please place config.env in the same folder as this script."
    exit 1
fi
source "$CONFIG_FILE"

cat <<EOF
============================================================
🧹 Hybrid NAS + Workstation Partial Cleanup Script
------------------------------------------------------------

This script will safely:

  • Stop services (Nextcloud, Jellyfin, Syncthing, etc.)
  • Clear logs and temporary files
  • Remove leftover config caches (non-destructive)
  • Reset firewall rules to default (optional)
  
It will NOT:

  • Remove installed packages or snaps
  • Delete user accounts or personal data
  • Unmount drives or remove mounts

Use this to refresh the system state without losing data.

============================================================
EOF

confirm() {
    read -r -p "$1 [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) true ;;
        *) false ;;
    esac
}

stop_services() {
    echo "[1] Stopping relevant services..."
    local services=(
        jellyfin
        syncthing@"$DEFAULT_USERNAME"
        tor
        cockpit
        fail2ban
        netdata
        nginx
        unattended-upgrades
    )
    for svc in "${services[@]}"; do
        echo "Stopping $svc..."
        sudo systemctl stop "$svc" || true
    done

    for user in $(echo "${USERS:-}" | tr ',' ' '); do
        echo "Stopping syncthing for user $user..."
        sudo systemctl stop syncthing@"$user" || true
    done
}

clear_logs() {
    echo "[2] Clearing logs and temporary files..."

    local log_dirs=(
        /var/log/jellyfin
        /var/log/syncthing
        /var/log/tor
        /var/log/fail2ban
        /var/log/nginx
        /var/log/cockpit
        /var/log/netdata
    )

    for d in "${log_dirs[@]}"; do
        if [[ -d "$d" ]]; then
            echo "Clearing $d"
            sudo rm -rf "$d"/*
        fi
    done

    sudo rm -rf /tmp/* /var/tmp/*
}

clear_caches() {
    echo "[3] Clearing leftover caches and config temp files..."

    local cache_dirs=(
        /home/"$DEFAULT_USERNAME"/.cache
        /home/"$DEFAULT_USERNAME"/.config/syncthing/cache
    )
    for user in $(echo "${USERS:-}" | tr ',' ' '); do
        cache_dirs+=( "/home/$user/.cache" "/home/$user/.config/syncthing/cache" )
    done

    for d in "${cache_dirs[@]}"; do
        if [[ -d "$d" ]]; then
            echo "Clearing $d"
            sudo rm -rf "$d"/*
        fi
    done
}

reset_firewall() {
    echo "[4] Reset firewall rules to default?"
    if confirm "Reset firewall rules?"; then
        sudo ufw reset -y
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow "$PORT_SSH"
        sudo ufw --force enable
        echo "Firewall reset complete."
    else
        echo "Skipping firewall reset."
    fi
}

echo "This script will stop services, clear logs and caches, and optionally reset the firewall."

if confirm "Proceed with partial cleanup?"; then
    stop_services
    clear_logs
    clear_caches
    reset_firewall
    echo "Partial cleanup completed successfully!"
else
    echo "Partial cleanup aborted."
fi


# Installation & Configuration Guide

This document guides you through setting up your Hybrid NAS + Personal Workstation system using the provided all-in-one script.

---

## Prerequisites

- A spare laptop or PC with Ubuntu 22.04 LTS or later installed.
- At least one external hard drive for NAS storage (formatted as ext4 recommended).
- Internet connectivity.
- Basic Linux command line familiarity.

---

## 1. Prepare Configuration File

Before running the setup script, customize the `config.env` file with your specific details.

Example `config.env`:

```bash
# User account that will run services like Syncthing
DEFAULT_USERNAME="yourusername"

# Mount point for external NAS drive
MOUNT_POINT="/mnt/nasdrive"

# Disk label for Samba share
DISK_LABEL="nasdrive"

# Dynamic DNS (DuckDNS) setup - leave blank if unused
DUCKDNS_DOMAIN="yourdomain.duckdns.org"
DUCKDNS_TOKEN="your-duckdns-token"

# WireGuard VPN configuration - change as needed
WG_PORT=51820
WG_IP="10.66.66.1/24"
````

> **Note:** Keep this file secure and **never share it publicly** as it contains sensitive info.

---

## 2. Running the Setup Script

1. Place the `setup-hybrid-nas-workstation.sh` script and the `config.env` file in the same directory.

2. Make sure the script is executable:

   ```bash
   chmod +x setup-hybrid-nas-workstation.sh
   ```

3. Run the script with sudo:

   ```bash
   sudo ./setup-hybrid-nas-workstation.sh
   ```

The script will:

* Update and upgrade the system
* Install and configure Nextcloud, Syncthing, Jellyfin, Samba
* Set up WireGuard VPN
* Configure Tor hidden service for Nextcloud
* Enable automatic backups with Restic
* Set up firewall, fail2ban, unattended-upgrades
* Enable monitoring dashboards (Cockpit and Netdata)
* Configure ZRAM swap and SMART monitoring

---

## 3. Post-Installation

### 3.1 Mounting Drives

* The external drive is mounted at the configured `MOUNT_POINT` (default: `/mnt/nasdrive`).
* Data directories like Nextcloud’s data are moved there to save space on the system disk.

### 3.2 Accessing Services

* **Nextcloud**:

  * Local: `http://localhost` or `http://<your-ip-address>`
  * Tor: `.onion` address displayed after script completes (check `/var/lib/tor/nextcloud_hidden/hostname`)

* **Syncthing**: `http://localhost:8384` (or `http://<ip>:8384`)

* **Jellyfin (Media Server)**: `http://localhost:8096`

* **Samba Share (LAN)**: Access via `\\<hostname>\<DISK_LABEL>` on Windows or `smb://<hostname>/<DISK_LABEL>` on Linux/macOS.

* **WireGuard VPN**: Configuration file generated at `/etc/wireguard/wg0.conf`. Import this in your VPN client.

* **Monitoring Dashboards**:

  * Cockpit: `https://<ip>:9090`
  * Netdata: `http://<ip>:19999`

### 3.3 Managing Backups

* Automated daily backups are handled by Restic.
* Backup repository is stored on the NAS drive (you can configure a remote repository as well).
* See [Backup & Restore](BACKUP.md) for details.

---

## 4. Configuration Adjustments

* You can update `config.env` at any time and rerun parts of the script if needed.
* For advanced customizations, check the service configuration files in `/etc` or their respective locations.

---

## 5. Updating the System & Services

* The system and installed snaps/packages can be updated via standard package managers:

```bash
sudo apt update && sudo apt upgrade -y
sudo snap refresh
```

* To update the setup script and config, pull the latest from the repo and rerun.

---

## 6. Recommended Security Practices

* Change default passwords and secure all services.
* Regularly check for updates.
* Use strong VPN client keys and Nextcloud passwords.
* Limit open ports on your firewall (UFW configured automatically).
* Consider adding 2FA to Nextcloud for additional protection.

---

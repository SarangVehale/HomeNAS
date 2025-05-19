# Maintenance & Upgrades

This document guides you on how to properly maintain and upgrade your Hybrid NAS + Workstation system to ensure stability, security, and new features.

---

## 1. Regular System Updates

Keeping your system and software up to date is critical for security and performance.

### Manual Update Commands

Run the following regularly:

```bash
sudo apt update && sudo apt upgrade -y
sudo snap refresh
````

### Automatic Security Updates

The setup includes unattended upgrades configured via:

```bash
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

Check logs for unattended-upgrades at:

```bash
cat /var/log/unattended-upgrades/unattended-upgrades.log
```

---

## 2. Upgrading Nextcloud Snap

To upgrade Nextcloud snap:

```bash
sudo snap refresh nextcloud
```

After upgrade, verify services are running:

```bash
sudo snap services nextcloud
```

---

## 3. Upgrading Jellyfin

Jellyfin installed from official repo can be updated with:

```bash
sudo apt update && sudo apt upgrade jellyfin
```

---

## 4. Updating WireGuard and Syncthing

* WireGuard updates come through system packages:

```bash
sudo apt update && sudo apt upgrade wireguard
```

* Syncthing updates via Snap or package manager:

```bash
sudo snap refresh syncthing
```

Or if installed via APT:

```bash
sudo apt update && sudo apt upgrade syncthing
```

---

## 5. Restarting Services After Upgrade

After upgrades, restart key services:

```bash
sudo systemctl restart nextcloud
sudo systemctl restart jellyfin
sudo systemctl restart tor
sudo systemctl restart fail2ban
sudo systemctl restart smb
sudo systemctl restart wg-quick@wg0
sudo systemctl --user restart syncthing.service
```

---

## 6. Kernel and System Upgrades

* If a kernel upgrade occurs, reboot is required:

```bash
sudo reboot
```

---

## 7. Checking Service Health After Upgrades

Use systemctl status or journalctl to confirm:

```bash
sudo systemctl status <service-name>
sudo journalctl -u <service-name> -b
```

---

## 8. Managing Snap Services

List all snaps:

```bash
snap list
```

Refresh all snaps:

```bash
sudo snap refresh
```

---

## 9. Backing Up Configuration Before Upgrades

Before major upgrades, backup config files and data:

```bash
sudo tar czvf backup_$(date +%F).tar.gz /etc /var/snap/nextcloud /home/$DEFAULT_USERNAME
```

---

## 10. Cleaning Up

To free disk space after upgrades:

```bash
sudo apt autoremove -y
sudo snap remove <unused-snap-package>
```

---

## Summary

Routine maintenance keeps your system secure and reliable. Automated updates reduce manual work but always verify post-upgrade stability.

---

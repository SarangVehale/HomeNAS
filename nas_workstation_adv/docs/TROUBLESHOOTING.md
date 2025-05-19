# Troubleshooting & FAQ

This document covers common issues, their solutions, and answers to frequently asked questions about the Hybrid NAS + Workstation setup.

---

## Common Issues & Fixes

### 1. Syncthing Service Fails to Start

**Symptom:**  
`Failed to enable/start Syncthing as a user service` or cannot access `http://localhost:8384`.

**Fix:**  
- Ensure the `DEFAULT_USERNAME` in `config.env` matches your Linux user.
- Run:

  ```bash
  sudo loginctl enable-linger $DEFAULT_USERNAME
  sudo systemctl --user daemon-reload
  sudo systemctl --user enable syncthing.service
  sudo systemctl --user start syncthing.service
````

* If still failing, check journal logs:

  ```bash
  sudo journalctl --user -u syncthing.service
  ```

---

### 2. External Drive Not Mounting

**Symptom:** Drive not accessible at `/mnt/nasdrive`.

**Fix:**

* Check the disk is connected:

  ```bash
  lsblk
  ```

* Verify `/etc/fstab` contains the correct UUID entry.

* Mount manually to check errors:

  ```bash
  sudo mount -a
  ```

* Ensure filesystem is ext4 or compatible.

---

### 3. Nextcloud Data Missing or Permissions Errors

**Symptom:** Nextcloud cannot read/write data or shows errors.

**Fix:**

* Confirm ownership:

  ```bash
  sudo chown -R $DEFAULT_USERNAME:$DEFAULT_USERNAME $MOUNT_POINT
  ```

* Check symbolic link exists:

  ```bash
  ls -l /var/snap/nextcloud/common/nextcloud/data
  ```

* Review Nextcloud logs:

  ```bash
  sudo snap logs nextcloud
  ```

---

### 4. Tor Hidden Service Not Working

**Symptom:** `.onion` address is missing or unreachable.

**Fix:**

* Check Tor service status:

  ```bash
  sudo systemctl status tor
  ```

* Confirm hidden service directory exists and has hostname file:

  ```bash
  sudo ls /var/lib/tor/nextcloud_hidden/hostname
  ```

* Restart Tor:

  ```bash
  sudo systemctl restart tor
  ```

---

### 5. Jellyfin Media Server Not Accessible

**Symptom:** Cannot open Jellyfin dashboard at port 8096.

**Fix:**

* Check Jellyfin service status:

  ```bash
  sudo systemctl status jellyfin
  ```

* Confirm firewall allows port 8096:

  ```bash
  sudo ufw status
  ```

---

### 6. VPN Connection Issues (WireGuard)

**Symptom:** Client cannot connect or no internet over VPN.

**Fix:**

* Confirm WireGuard is running:

  ```bash
  sudo systemctl status wg-quick@wg0
  ```

* Verify client config matches server public key and allowed IPs.

* Check firewall rules and NAT forwarding.

---

## FAQ

### Q1: Can I use this setup on a different Linux distribution?

This script is tested on Ubuntu 22.04 LTS and newer. Other Debian-based distros may work but are not officially supported.

---

### Q2: How do I add more users to Samba or Nextcloud?

* Samba: Add users with `sudo smbpasswd -a username`.
* Nextcloud: Manage users via Nextcloud’s web interface as admin.

---

### Q3: How can I update or upgrade the system?

Run:

```bash
sudo apt update && sudo apt upgrade -y
sudo snap refresh
```

---

### Q4: How do I stop or restart individual services?

Use:

```bash
sudo systemctl restart <service-name>
sudo systemctl stop <service-name>
sudo systemctl start <service-name>
```

Common services include: `nextcloud`, `syncthing@$DEFAULT_USERNAME`, `jellyfin`, `tor`, `wg-quick@wg0`, `fail2ban`, `smbd`.

---

### Q5: How do I check logs for troubleshooting?

* System logs:

  ```bash
  journalctl -u <service-name>
  ```

* Snap logs for Nextcloud:

  ```bash
  sudo snap logs nextcloud
  ```

* User service logs (Syncthing):

  ```bash
  sudo journalctl --user -u syncthing.service
  ```

---

### Q6: What if I lose my VPN config file?

You can regenerate the WireGuard client config from the server setup or create a new peer by running the relevant script commands. Backup your configs securely.

---

## Need More Help?

Open an issue or discussion on the project’s GitHub repository with detailed information about your problem.

---


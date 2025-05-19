# Verification & Monitoring

This document explains how to verify the correct functioning of your Hybrid NAS + Workstation services and how to monitor their status for ongoing health checks.

---

## Verifying Service Status

You can check the status of key services using `systemctl` or related commands.

### Check All Key Services

```bash
sudo systemctl status nextcloud
sudo systemctl status jellyfin
sudo systemctl status tor
sudo systemctl status fail2ban
sudo systemctl status smb
sudo systemctl status wg-quick@wg0
sudo systemctl status syncthing@$DEFAULT_USERNAME
````

### Syncthing User Service

Syncthing runs as a user service:

```bash
sudo loginctl enable-linger $DEFAULT_USERNAME
sudo systemctl --user status syncthing.service
```

---

## Accessing Web Interfaces

* **Nextcloud:**
  `http://localhost` or via your Tor `.onion` address (see `/var/lib/tor/nextcloud_hidden/hostname`)

* **Jellyfin:**
  `http://localhost:8096`

* **Syncthing:**
  `http://localhost:8384`

* **WireGuard (VPN):**
  Managed via client configurations, no web UI by default.

---

## Logs for Monitoring

To diagnose or monitor service health, check logs:

```bash
# System-wide services
sudo journalctl -u nextcloud
sudo journalctl -u jellyfin
sudo journalctl -u tor
sudo journalctl -u fail2ban
sudo journalctl -u smb
sudo journalctl -u wg-quick@wg0

# User services (Syncthing)
sudo journalctl --user -u syncthing.service
```

---

## System Resource Monitoring

* Use **Netdata** dashboard if installed, accessible via:

  ```
  http://localhost:19999
  ```

* Alternatively, use command-line tools:

  ```bash
  top
  htop
  free -h
  df -h
  iostat
  ```

---

## Automatic Alerts

* Fail2Ban will automatically block IPs showing suspicious behavior.
* UFW firewall logs can be checked for blocked attempts:

  ```bash
  sudo tail -f /var/log/ufw.log
  ```

---

## Recommended Monitoring Tools

* **Netdata:** Real-time health monitoring (optional install)
* **Cockpit:** Web-based server admin interface
* **Prometheus + Grafana:** For advanced metrics and dashboards (advanced users)

---

## Summary

Regularly verify service status and review logs to ensure smooth operation. Monitoring helps preemptively catch issues and maintain uptime.


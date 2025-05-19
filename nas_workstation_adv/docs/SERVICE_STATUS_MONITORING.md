# Service Status & Monitoring

This document explains how to check the health, status, and logs of key services in your Hybrid NAS + Workstation system, as well as monitoring tools you can use.

---

## 1. Checking Service Status with systemctl

Use the following commands to check whether a service is running and enabled:

```bash
sudo systemctl status <service-name>
sudo systemctl is-enabled <service-name>
````

Common service names in this setup:

| Service Name     | Description                    |
| ---------------- | ------------------------------ |
| nextcloud        | Nextcloud snap service         |
| jellyfin         | Jellyfin media server          |
| tor              | Tor anonymity network service  |
| fail2ban         | Brute-force protection         |
| smbd             | Samba file sharing service     |
| wg-quick\@wg0    | WireGuard VPN interface        |
| syncthing (user) | Syncthing file sync (per-user) |

**Example:**

```bash
sudo systemctl status jellyfin
sudo systemctl status tor
sudo systemctl status fail2ban
```

---

## 2. Checking Syncthing User Service

Syncthing runs as a user service. Check status by switching to the user:

```bash
sudo -u $DEFAULT_USERNAME systemctl --user status syncthing.service
```

To restart:

```bash
sudo -u $DEFAULT_USERNAME systemctl --user restart syncthing.service
```

---

## 3. Viewing Logs

Use `journalctl` to view service logs:

```bash
sudo journalctl -u <service-name> -f
```

This shows real-time logs. Example:

```bash
sudo journalctl -u nextcloud -f
```

For Syncthing logs (user service):

```bash
sudo -u $DEFAULT_USERNAME journalctl --user -u syncthing.service -f
```

---

## 4. Monitoring with Netdata

If installed, Netdata provides a web dashboard with real-time metrics:

* Access it at: `http://localhost:19999` or `http://<server-ip>:19999`

Start or restart Netdata service:

```bash
sudo systemctl start netdata
sudo systemctl enable netdata
```

---

## 5. Using Cockpit for System Management

Cockpit offers a web-based interface to monitor system health:

* Access it at: `http://localhost:9090` or `http://<server-ip>:9090`

Start or enable Cockpit:

```bash
sudo systemctl start cockpit
sudo systemctl enable cockpit
```

---

## 6. Checking Disk Usage

To check disk space usage on your NAS mount:

```bash
df -h $MOUNT_POINT
```

To check inode usage (files count):

```bash
df -i $MOUNT_POINT
```

---

## 7. Network and Firewall Status

Check UFW firewall status:

```bash
sudo ufw status verbose
```

Check active network interfaces and IP addresses:

```bash
ip a
```

---

## 8. Verifying Backup Health (Restic)

See snapshot list:

```bash
restic snapshots
```

Test restoring files or directories from snapshots as needed (see Backup & Restore doc).

---

## 9. Service Restart Commands

If a service is unresponsive, restart it:

```bash
sudo systemctl restart <service-name>
```

For Syncthing user service:

```bash
sudo -u $DEFAULT_USERNAME systemctl --user restart syncthing.service
```

---

## Summary

Regularly check service statuses and logs to ensure smooth operation. Use monitoring tools for real-time insights.

---


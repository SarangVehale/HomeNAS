# Security & Privacy Best Practices

This document outlines best practices to secure your Hybrid NAS + Workstation system and protect your privacy.

---

## 1. Keep Your System Updated

- Regularly run system updates:

  ```bash
  sudo apt update && sudo apt upgrade -y
````

* The setup includes unattended security upgrades, but manual checks are recommended.

---

## 2. Use Strong Passwords and SSH Keys

* Use strong, unique passwords for all accounts.

* For remote SSH access, prefer SSH keys over passwords.

* Disable password-based SSH authentication if possible:

  ```bash
  sudo nano /etc/ssh/sshd_config
  # Set:
  PasswordAuthentication no
  ```

* Restart SSH:

  ```bash
  sudo systemctl restart ssh
  ```

---

## 3. Firewall Configuration (UFW)

* The script enables UFW with essential ports open.
* Only open necessary ports.
* To check UFW status:

  ```bash
  sudo ufw status verbose
  ```

---

## 4. Fail2Ban Brute-Force Protection

* Fail2Ban monitors logs and blocks suspicious IPs.
* Check banned IPs:

  ```bash
  sudo fail2ban-client status
  sudo fail2ban-client status sshd
  ```

---

## 5. Tor Hidden Services

* Nextcloud is accessible over Tor for privacy.

* Keep the Tor hidden service directory secure:

  ```bash
  sudo chmod 700 /var/lib/tor/nextcloud_hidden
  ```

* Do **not** share the `.onion` address publicly unless intended.

---

## 6. SSL/TLS Certificates

* Use Let’s Encrypt certificates for encrypted HTTPS connections.
* Certificates auto-renew via Certbot cron jobs.
* Regularly verify certificate validity:

  ```bash
  sudo certbot renew --dry-run
  ```

---

## 7. Regular Backups

* Backups with Restic protect your data against loss or corruption.
* Store backups offsite if possible.
* Test backup restorations regularly.

---

## 8. User Account and Permissions

* Limit user privileges; avoid running services as root.
* Use `sudo` carefully.
* Set correct ownership and permissions on NAS shares:

  ```bash
  sudo chown -R $DEFAULT_USERNAME:$DEFAULT_USERNAME $MOUNT_POINT
  ```

---

## 9. Monitoring and Alerts

* Monitor system logs and service status regularly.
* Use tools like Fail2Ban, Netdata, or Cockpit for alerts.
* Review logs for unauthorized access attempts.

---

## 10. VPN Security (WireGuard)

* Use WireGuard to securely access your network remotely.
* Keep VPN client configs private.
* Revoke or regenerate keys if a device is compromised.

---

## 11. Additional Tips

* Avoid exposing unnecessary services to the internet.
* Use strong encryption for data at rest and in transit.
* Regularly audit your system security.
* Consider setting up multi-factor authentication (MFA) for critical services.

---

## Useful Resources

* [Ubuntu Security Guide](https://ubuntu.com/security)
* [Nextcloud Security](https://nextcloud.com/security/)
* [Fail2Ban Documentation](https://www.fail2ban.org/wiki/index.php/Main_Page)
* [Tor Project](https://www.torproject.org/)
* [WireGuard Documentation](https://www.wireguard.com/)

---


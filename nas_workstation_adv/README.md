# Hybrid NAS + Personal Workstation Setup

Automated all-in-one script to convert a spare laptop or server into a powerful hybrid NAS and personal cloud workstation.

---

## 📚 Documentation Overview

For detailed instructions and reference, please consult the following documents:

- [Installation & Configuration](docs/INSTALLATION.md)  
  Step-by-step setup guide, configuration details, and prerequisites.

- [Troubleshooting & FAQ](docs/TROUBLESHOOTING.md)  
  Common issues, fixes, and answers to frequently asked questions.

- [Backup & Restore with Restic](docs/BACKUP.md)  
  How to use the automated backup system and restore files securely.

- [Security & Network](docs/SECURITY.md)  
  Explanation of firewall, VPN, Tor, SSL, and best security practices.

- [Service Management & Useful Commands](docs/SERVICES.md)  
  How to check status, start, stop, and manage installed services.

---

## 🚀 Features Summary

- Nextcloud private cloud with Tor hidden service access
- Syncthing peer-to-peer file synchronization
- Jellyfin media streaming server
- Samba file sharing for LAN
- WireGuard VPN server for secure remote access
- Cockpit and Netdata web dashboards for system monitoring
- Automated encrypted backups with Restic
- Disk health monitoring via SMART
- Automatic OS security updates and fail2ban protection
- ZRAM swap for better memory management

---

## 🛠️ Quick Start

1. Review and customize `config.env` to suit your environment.
2. Run the setup script:

   ```bash
   sudo ./setup-hybrid-nas-workstation.sh
````

3. Access your services as documented in the respective sections.

---

## 📝 Contributing

Issues and pull requests are welcome! Please adhere to best practices and provide detailed information.

---

## 📜 License

MIT License — see `LICENSE` file for details.

---

## 🤝 Acknowledgments

Thanks to the open source communities of Nextcloud, Syncthing, Jellyfin, WireGuard, Restic, and many others.

---

For any immediate questions or feedback, please check the [Troubleshooting & FAQ](docs/TROUBLESHOOTING.md) first.

---

Happy self-hosting! 🎉




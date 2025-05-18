### **Hybrid NAS + Workstation Setup Script Documentation**

---

## **Overview**

This script automates the setup of a **hybrid NAS (Network-Attached Storage)** and **workstation system** on a Linux machine. It is designed to provide a seamless experience by automatically installing and configuring services like **Nextcloud** (for personal cloud storage), **Jellyfin** (for media streaming), **Samba** (for file sharing), **Syncthing** (for file syncing), **Tor** (for privacy), and **fail2ban** (for security). The script also configures SSL certificates (via Let's Encrypt) and optionally integrates with **Dynamic DNS (DuckDNS)** for remote access.

The script is **production-ready**, designed to be run on a fresh system or as a part of a new setup. It includes **error handling** and outputs meaningful error messages when a failure occurs.

---

## **System Requirements**

* A Linux-based system (Ubuntu/Debian recommended)
* A spare laptop or desktop that can be repurposed as a server
* An external storage drive for NAS functionality
* **Root (sudo)** access to the machine
* **Dynamic DNS** and **SSL** are optional but can be configured during setup
* **Tor** should be available for setting up Nextcloud with a hidden service (`.onion` domain)

---

## **Features**

1. **Nextcloud**: Provides personal cloud storage, file sharing, and syncing with external devices.
2. **Jellyfin**: Media server to manage and stream your media content (movies, TV shows, music).
3. **Samba**: LAN file sharing service to share data between devices in a local network.
4. **Syncthing**: Securely sync files between devices, ensuring data consistency and redundancy.
5. **Tor Hidden Service**: Nextcloud will be accessible through a **.onion** address over the Tor network, ensuring privacy and security.
6. **Fail2Ban**: Protects the server from brute-force attacks by blocking malicious IPs.
7. **Unattended Upgrades**: Automatically installs security updates to keep the system secure.
8. **Firewall Configuration (UFW)**: Ensures only essential ports are open (SSH, HTTP, HTTPS, Samba, etc.).
9. **Dynamic DNS** (DuckDNS): Updates your external IP address and allows remote access to services using a domain name.
10. **SSL (Optional)**: Secures the web traffic to your services (Nextcloud, Jellyfin, etc.) using **Let's Encrypt** certificates.

---

## **Detailed Functionality and Configuration**

### **Step-by-Step Breakdown**

---

### **1. System Update and Package Installation**

```bash
sudo apt update
sudo apt upgrade -y
```

* Updates the system and installs necessary packages (`curl`, `tor`, `ufw`, `samba`, `syncthing`, etc.).

### **2. Installing and Enabling Syncthing**

```bash
sudo systemctl enable syncthing@$DEFAULT_USERNAME.service
sudo systemctl start syncthing@$DEFAULT_USERNAME.service
```

* **Syncthing** is installed and configured to sync files between devices. It’s enabled as a service for the current user and started.

### **3. Configuring Unattended Upgrades**

```bash
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

* **Unattended Upgrades** ensures that security updates are automatically applied to the system.

### **4. Enabling and Starting Fail2Ban**

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

* **Fail2Ban** is enabled to protect against brute-force attacks by blocking IPs with too many failed login attempts.

### **5. Firewall Configuration (UFW)**

```bash
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw allow 32400
sudo ufw allow 8384
sudo ufw enable
```

* Configures the firewall to allow traffic for **SSH**, **HTTP**, **HTTPS**, **Jellyfin**, and **Syncthing**.

### **6. Mount External Drive for NAS**

```bash
sudo mkdir -p $MOUNT_POINT
sudo mount -a
```

* This step automatically mounts the external storage device and ensures that it's persistently mounted on system reboot by adding it to `/etc/fstab`.

### **7. Installing Nextcloud (Snap Version)**

```bash
sudo snap install nextcloud
sudo snap stop nextcloud
sudo mv /var/snap/nextcloud/common/nextcloud/data "$NEXTCLOUD_DATA"
```

* Installs **Nextcloud** using **Snap**, then moves the Nextcloud data to the configured **external drive** (NAS). The service is then restarted with the new data directory.

### **8. Configuring Tor Hidden Service for Nextcloud**

```bash
sudo systemctl restart tor
```

* **Nextcloud** is configured to be accessible over the Tor network as a **hidden service**, providing a **.onion** address for privacy.

### **9. Installing Jellyfin (Media Server)**

```bash
wget -O - https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/jellyfin.gpg
```

* Installs **Jellyfin**, a media server to manage and stream movies, TV shows, and music.

### **10. Configuring Samba for LAN File Sharing**

```bash
sudo tee -a /etc/samba/smb.conf
```

* Sets up **Samba** to allow file sharing over the local network. The external storage (NAS) is shared under the name `nasdrive`.

### **11. Setting Permissions on External Storage**

```bash
sudo chown -R $DEFAULT_USERNAME:$DEFAULT_USERNAME "$MOUNT_POINT"
```

* Sets the correct file ownership and permissions for the mounted storage.

### **12. Optional Dynamic DNS Configuration**

```bash
echo "*/5 * * * * curl -s https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip=" | sudo tee -a /etc/crontab
```

* If **Dynamic DNS (DuckDNS)** is configured, a cron job is set up to periodically update the external IP address with DuckDNS.

### **13. Setting Up SSL via Let's Encrypt (Optional)**

```bash
sudo certbot --nginx -d $DUCKDNS_DOMAIN
```

* **SSL certificates** are obtained for the domain via **Let's Encrypt**, securing the communication with the services.

---

## **Error Handling Mechanism**

* The script uses the `error_exit` function to ensure that if any command fails, the script stops immediately, and a descriptive error message is shown.
* If any command fails, it exits with a helpful error message that indicates which part of the process failed.

### **Common Errors**

1. **Package Installation Errors**: Ensure you have an active internet connection and check if the repositories are up to date.
2. **Disk Mounting Issues**: Verify that the external drive is connected and properly recognized by the system.
3. **Tor Service Issues**: Ensure that the **Tor** service is correctly installed and running on the system.

---

## **Customizable Parameters**

* `MOUNT_POINT`: Path where external storage is mounted (default: `/mnt/nasdrive`).
* `NEXTCLOUD_DATA`: Path to the Nextcloud data directory (default: `$MOUNT_POINT/nextcloud-data`).
* `TOR_SERVICE_DIR`: Directory for storing Tor hidden service data (default: `/var/lib/tor/nextcloud_hidden`).
* `DEFAULT_USERNAME`: The current system user running the script.
* `DISK_LABEL`: The label of the disk used for the NAS.

### **Dynamic DNS (DuckDNS)**:

* Set `DUCKDNS_TOKEN` and `DUCKDNS_DOMAIN` with your **DuckDNS** account token and domain.

---

## **Post-Setup Access**

After the script completes, you can access your services:

* **Nextcloud**: `http://localhost` or the **Tor .onion** address (`http://<your_onion>.onion`).
* **Samba (LAN)**: `\\<hostname>\nasdrive` for LAN file sharing.
* **Syncthing**: `http://localhost:8384` for file syncing.
* **Jellyfin (Media Server)**: `http://localhost:8096` for media streaming.

---

## **Troubleshooting**

* **Nextcloud won't start**: Check the Nextcloud logs in `/var/snap/nextcloud/current/logs/` for more information.
* **Samba share not visible**: Ensure that your firewall allows Samba traffic and check the Samba service status.
* **Tor hidden service not working**: Check Tor logs (`/var/log/tor/tor.log`) for any errors with the hidden service.

---

## **Additional Notes**

* You can configure **additional backups**, use **rclone** for cloud syncing, or integrate a **webcam security system** such as **MotionEye**.
* For **media transcoding** in Jellyfin, ensure you have the necessary **hardware acceleration** enabled in your Jellyfin settings.

---

## **Conclusion**

This script provides a **fully automated, production-ready setup** for a hybrid NAS and workstation system. It supports a variety of services (Nextcloud, Jellyfin, Syncthing, Samba) and ensures privacy and security through Tor, SSL, and fail2ban.

Feel free to modify the script as needed for additional services or custom configurations!

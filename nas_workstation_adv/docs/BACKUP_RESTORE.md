# Backup & Restore with Restic

This document explains how backups are managed using Restic, how to perform manual backups, and how to restore data if needed.

---

## What is Restic?

[Restic](https://restic.net/) is a fast, efficient, and secure open-source backup program. It supports encrypted backups, incremental snapshots, and works well with local or remote storage.

In this setup, Restic is used to backup your important data (Nextcloud data directory, media files, configuration files, etc.) to a secure backup location.

---

## Backup Configuration

- Backup Source(s):  
  - Nextcloud data: `$NEXTCLOUD_DATA`  
  - External storage mount: `$MOUNT_POINT`  
  - Samba shares or other important config directories can be added as needed.

- Backup Destination:  
  - Local or remote directory configured in `config.env` under `RESTIC_REPOSITORY`  
  - Restic password stored in `RESTIC_PASSWORD`

---

## How to Perform a Manual Backup

1. Source the configuration variables:

   ```bash
   source config.env
````

2. Run the backup command:

   ```bash
   restic backup $NEXTCLOUD_DATA $MOUNT_POINT
   ```

3. Verify backup completed successfully.

---

## Automating Backups

The setup includes a cron job to run Restic backup every night at 2 AM.

* To see the cron job, run:

  ```bash
  sudo crontab -l
  ```

* Cron entry looks like:

  ```
  0 2 * * * /usr/local/bin/restic backup $NEXTCLOUD_DATA $MOUNT_POINT
  ```

---

## How to Restore from Backup

### 1. Initialize Restic Repository (if not done)

If starting on a new system, initialize or restore the repo with:

```bash
restic init
```

*Note: Skip if repo already exists.*

### 2. List Available Snapshots

Check available backups (snapshots):

```bash
restic snapshots
```

### 3. Restore Files

To restore the latest snapshot to a directory (e.g., `/restore`):

```bash
restic restore latest --target /restore
```

Or to restore specific files/folders:

```bash
restic restore latest --include path/to/file --target /restore
```

---

## Backup Verification

* To verify the integrity of backups:

  ```bash
  restic check
  ```

* To list contents of a snapshot:

  ```bash
  restic ls latest
  ```

---

## Additional Restic Commands

* Forget old backups and prune:

  ```bash
  restic forget --keep-last 7 --prune
  ```

* See backup stats:

  ```bash
  restic stats
  ```

---

## Tips

* Always keep your `RESTIC_PASSWORD` safe and backed up securely.
* Regularly test your backups by restoring small files.
* Use encrypted remote storage for offsite backup (optional).

---

## Useful Links

* [Restic Official Documentation](https://restic.readthedocs.io/en/stable/)
* [Restic GitHub](https://github.com/restic/restic)

---


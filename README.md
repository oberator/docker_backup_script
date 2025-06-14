# Docker Backup Script with Gotify Notifications

This small script automates the process of backing up Docker containers specified by their respective `docker-compose.yml` files. It stops the containers, creates backups of their directories, and then restarts the containers. 
Optionally, it can send notifications through Gotify about the success or failure of the backup process.

**Note:** The script assumes that all data of the container is contained in the respective root folder specified in the `directories.txt` file. If additional data is stored elsewhere, you may need to adjust the script accordingly.

## Features
- Backup multiple Docker containers defined by `docker-compose.yml`.
- Preserve file permissions during backup.
- Optional Gotify notifications to inform about the success or failure of each backup.
- Log of all actions and errors in a log file.

## Setup and Configuration

### 1. **Clone the Repository**
First, clone this repository to your docker host:

```bash
git clone https://github.com/oberator/docker_backup_script
cd docker_backup_script
```

### 2. **Configure Variables**
Before running the script, copy the sample configuration files and edit them to your needs:

```bash
cp backup.conf.sample backup.conf
cp directories.txt.sample directories.txt
```

- `backup.conf`: Contains variables such as backup path, log file, Gotify settings, and max backups.
- `directories.txt`: List of directories (one per line) containing `docker-compose.yml` files for the containers you want to back up. Comment out lines with `#` to skip them.

#### Example `backup.conf`
```
# Backup destination path
BACKUP_PATH="/srv/backup"
LOG_FILE="${BACKUP_PATH}/logs/backup.log"

# Gotify API details
GOTIFY_URL="https://gotify.example.com/message"
GOTIFY_TOKEN="your-gotify-token"
GOTIFY_MESSAGING=true  # Set to false to disable Gotify notifications

MAX_BACKUPS=5
```

#### Example `directories.txt`
```
/opt/containers/container1
/opt/containers/container2
#/opt/containers/container3
```

### 3. **Install Dependencies**
Ensure that you have the following installed:
- Docker
- Docker Compose
- curl (for Gotify notifications)

### 4. **Running the Script**
Once you've configured the script, you can run it manually with the following command:

```bash
sudo bash backup.sh
```

You can make the script executable with 
```
chmod +x backup.sh
```

You can add it to cron with `crontab -e` or `sudo crontab -e` (if your directories need root access) adding the line 

```
0 1 * * * /opt/containers/docker_backup_script/backup.sh
```

### 5. **Restoring a Backup**

To restore a backup created by this script:

1. Stop the relevant Docker container:
   ```bash
   cd /path/to/your/container
   docker-compose down
   ```
2. Locate your backup archive (e.g., `/srv/backup/container1/backup-YYYYMMDD_HHMMSS.tar.gz`).
3. Extract the backup to the container directory, replacing existing files:
   ```bash
   tar -xvzf /srv/backup/container1/backup-YYYYMMDD_HHMMSS.tar.gz -C /opt/containers/container1 --strip-components=1
   ```
4. Restart the container:
   ```bash
   docker-compose up -d
   ```

**Note:** Adjust paths and filenames as needed. Make sure to review the extracted files before starting the container.

### 6. Notification Configuration
If GOTIFY_MESSAGING is set to true, notifications will be sent to your Gotify server after each container is backed up. These notifications will include details about the backup, including the size of the backup and whether the backup was successful.
If GOTIFY_MESSAGING is set to false, no notifications will be sent, but the backup process will still proceed as normal.

## License
This script is licensed under the MIT License.

## Disclaimer
Please review the script before running it in a production environment. Ensure that you have backups of critical data and understand the functionality of the script. The script assumes all data for the container is contained in the respective root folder. If additional data is stored outside these directories, you may need to adjust the script accordingly.

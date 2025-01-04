# Docker Backup Script with Gotify Notifications

This small script automates the process of backing up Docker containers specified by their respective `docker-compose.yml` files. It stops the containers, creates backups of their directories, and then restarts the containers. 
Optionally, it can send notifications through Gotify about the success or failure of the backup process.

**Note:** The script assumes that all data of the container is contained in the respective root folder specified in the `DIRECTORIES` array. If additional data is stored elsewhere, you may need to adjust the script accordingly.

## Features
- Backup multiple Docker containers defined by `docker-compose.yml`.
- Preserve file permissions during backup.
- Optional Gotify notifications to inform about the success or failure of each backup.
- Log of all actions and errors in a log file.

## Setup and Configuration

### 1. **Configure Variables**
Before running the script, you need to configure the following variables:

- `BACKUP_PATH`: The directory where backups will be stored.
- `LOG_FILE`: Path to the log file where all actions will be logged.
- `DIRECTORIES`: Array of directories containing `docker-compose.yml` files for the containers you want to back up.
- `GOTIFY_URL`: URL of your Gotify server.
- `GOTIFY_TOKEN`: The Gotify API token for sending notifications.
- `GOTIFY_MESSAGING`: Set this to `true` to enable Gotify notifications, or `false` to disable them.

### 2. **Install Dependencies**
Ensure that you have the following installed:
- Docker
- Docker Compose
- curl (for Gotify notifications)

### 3. **Running the Script**
Once you've configured the script, you can run it manually with the following command:

```bash
sudo ./docker-backup.sh
```

You can make the script executable with 
```
chmod +x docker-backup.sh
```

You can add it to cron with ```crontab -e``` or ```sudo crontab -e``` (if your directories need root access) adding the line 

```
0 1 * * * /your/path/to/script/backup.sh
```

### 4. Notification Configuration
If GOTIFY_MESSAGING is set to true, notifications will be sent to your Gotify server after each container is backed up. These notifications will include details about the backup, including the size of the backup and whether the backup was successful.
If GOTIFY_MESSAGING is set to false, no notifications will be sent, but the backup process will still proceed as normal.

### 5. Example Configuration 
```
# Backup destination path
BACKUP_PATH="/path/to/backup"
LOG_FILE="/path/to/backup/backup.log"

# Gotify API details
GOTIFY_URL="https://gotify.example.com/message"
GOTIFY_TOKEN="your-gotify-token"
GOTIFY_MESSAGING=true  # Set to false to disable Gotify notifications

# Directories containing docker-compose.yml to backup
DIRECTORIES=(
    "/path/to/container1"
    "/path/to/container2"
    "/path/to/container3"
)
...
```

## License
This script is licensed under the MIT License.

## Disclaimer
Please review the script before running it in a production environment. Ensure that you have backups of critical data and understand the functionality of the script. The script assumes all data for the container is contained in the respective root folder. If additional data is stored outside these directories, you may need to adjust the script accordingly.

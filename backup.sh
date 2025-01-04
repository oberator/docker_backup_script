#!/bin/bash

# Backup destination path
BACKUP_PATH="/path/to/backup"
LOG_FILE="/path/to/backup/backup.log"

# Gotify API details
GOTIFY_URL="https://gotify.example.com/message"  # Replace with your Gotify URL
GOTIFY_TOKEN="your-gotify-token"                # Replace with your Gotify API token
GOTIFY_MESSAGING=true  # Set to true to enable Gotify notifications, false to disable

# Directories containing docker-compose.yml to backup
# If you want to skip a directory just add a "#" before.
DIRECTORIES=(
    "/path/to/container1"
    "/path/to/container2"
   #"/path/to/container3"
)

# Ensure backup path and log file exist
sudo mkdir -p "$BACKUP_PATH"
sudo touch "$LOG_FILE"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" > /dev/null
}

# Send a Gotify notification (if GOTIFY_MESSAGING=true)
send_notification() {
    local title="$1"
    local message="$2"
    local priority="$3"

    if [ "$GOTIFY_MESSAGING" = true ]; then
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$GOTIFY_URL?token=$GOTIFY_TOKEN" \
            -F "title=$title" \
            -F "message=$message" \
            -F "priority=$priority")
        
        if [ "$RESPONSE" -ne 200 ]; then
            log "Failed to send Gotify notification. HTTP response code: $RESPONSE"
        fi
    fi
}

log "Backup process started."

# Loop through each directory and process it
for DIR in "${DIRECTORIES[@]}"; do
    # Skip directories that start with a `#`
    if [[ "$DIR" =~ ^# ]]; then
        continue
    fi

    if [ -d "$DIR" ] && [ -f "$DIR/docker-compose.yml" ]; then
        CONTAINER_NAME="$(basename "$DIR")"  # Extract container name
        log "Processing directory: $DIR ($CONTAINER_NAME)"

        # Stop the containers
        log "Stopping containers in $DIR..."
        sudo docker compose -f "$DIR/docker-compose.yml" down | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "Failed to stop containers in $DIR. Skipping backup for this directory."
            send_notification "Backup Failed: $CONTAINER_NAME" "Failed to stop containers in $DIR. Skipping backup." 5
            continue
        fi

        # Create a timestamped archive name
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        ARCHIVE_NAME="${CONTAINER_NAME}_$TIMESTAMP.tar.gz"

        # Create a compressed backup with preserved permissions
        log "Creating backup for $DIR..."
        sudo tar --preserve-permissions -czvf "$BACKUP_PATH/$ARCHIVE_NAME" -C "$(dirname "$DIR")" "$(basename "$DIR")" | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "Failed to create backup for $DIR. Skipping..."
            send_notification "Backup Failed: $CONTAINER_NAME" "Failed to create backup for $DIR. Skipping." 5
            continue
        fi

        # Get the size of the backup file
        BACKUP_SIZE=$(sudo du -sh "$BACKUP_PATH/$ARCHIVE_NAME" | cut -f1)
        log "Backup of $DIR completed: $BACKUP_PATH/$ARCHIVE_NAME (Size: $BACKUP_SIZE)"
        send_notification "Backup Successful: $CONTAINER_NAME" "Backup of $DIR completed: $BACKUP_PATH/$ARCHIVE_NAME (Size: $BACKUP_SIZE)" 5

        # Restart the containers
        log "Restarting containers in $DIR..."
        sudo docker compose -f "$DIR/docker-compose.yml" up -d | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "Failed to restart containers in $DIR. Please check manually."
            send_notification "Backup Warning: $CONTAINER_NAME" "Backup successful for $DIR, but restarting containers failed. Please check manually." 4
        else
            log "Containers in $DIR restarted successfully."
        fi
    else
        log "Directory $DIR does not exist or does not contain a docker-compose.yml file. Skipping..."
        send_notification "Backup Skipped" "Directory $DIR does not exist or is missing docker-compose.yml. Skipping." 3
    fi
done

log "Backup process completed."
send_notification "Backup Process Completed" "All directories have been processed. Check log for details." 6

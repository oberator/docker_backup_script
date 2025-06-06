#!/bin/bash

# Load configuration variables
source "$(dirname "$0")/backup.conf"

# Read directories from directories.txt, ignoring comments and empty lines
mapfile -t DIRECTORIES < <(grep -vE '^[[:space:]]*#' "$(dirname "$0")/directories.txt" | grep -vE '^[[:space:]]*$')

# Ensure backup path and log file directory exist
sudo mkdir -p "$BACKUP_PATH"
sudo mkdir -p "$(dirname "$LOG_FILE")"
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

rotate_backups() {
    local backups=($(ls -1t "$BACKUP_PATH"/*.tar.gz 2>/dev/null))
    local count=${#backups[@]}
    if (( count > MAX_BACKUPS )); then
        for ((i=MAX_BACKUPS; i<count; i++)); do
            log "Removing old backup: ${backups[$i]}"
            rm -f "${backups[$i]}"
        done
    fi
}

log "Backup process started."

# Accumulate notifications
NOTIFICATIONS=()

# Loop through each directory and process it
for DIR in "${DIRECTORIES[@]}"; do
    # Skip directories that start with a `#`
    if [[ "$DIR" =~ ^# ]]; then
        log "Skipping directory: ${DIR#"#"} (commented out)"
        continue
    fi

    if [ -d "$DIR" ] && [ -f "$DIR/docker-compose.yml" ]; then
        CONTAINER_NAME="$(basename "$DIR")"  # Extract container name
        log "Processing directory: $DIR ($CONTAINER_NAME)"

        # Stop the containers
        log "Stopping containers in $DIR..."
        sudo docker compose -f "$DIR/docker-compose.yml" down | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            MESSAGE="Failed to stop containers in $DIR. Skipping backup."
            log "$MESSAGE"
            NOTIFICATIONS+=("Backup Failed: $CONTAINER_NAME - $MESSAGE")
            continue
        fi

        # Create a timestamped archive name
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        ARCHIVE_NAME="${CONTAINER_NAME}_$TIMESTAMP.tar.gz"

        # Create a compressed backup with preserved permissions
        log "Creating backup for $DIR..."
        sudo tar --preserve-permissions -czf "$BACKUP_PATH/$ARCHIVE_NAME" -C "$(dirname "$DIR")" "$(basename "$DIR")"
        if [ $? -ne 0 ]; then
            MESSAGE="Failed to create backup for $DIR. Skipping."
            log "$MESSAGE"
            NOTIFICATIONS+=("Backup Failed: $CONTAINER_NAME - $MESSAGE")
            continue
        fi

        # Get the size of the backup file
        BACKUP_SIZE=$(sudo du -sh "$BACKUP_PATH/$ARCHIVE_NAME" | cut -f1)
        log "Backup of $DIR completed: $BACKUP_PATH/$ARCHIVE_NAME (Size: $BACKUP_SIZE)"
        NOTIFICATIONS+=("Backup Successful: $CONTAINER_NAME - $BACKUP_PATH/$ARCHIVE_NAME (Size: $BACKUP_SIZE)")

        # Restart the containers
        log "Restarting containers in $DIR..."
        sudo docker compose -f "$DIR/docker-compose.yml" up -d | tee -a "$LOG_FILE"
        if [ $? -ne 0 ]; then
            MESSAGE="Backup successful for $DIR, but restarting containers failed. Please check manually."
            log "$MESSAGE"
            NOTIFICATIONS+=("Backup Warning: $CONTAINER_NAME - $MESSAGE")
        else
            log "Containers in $DIR restarted successfully."
        fi
    else
        MESSAGE="Directory $DIR does not exist or does not contain a docker-compose.yml file. Skipping."
        log "$MESSAGE"
        NOTIFICATIONS+=("Backup Skipped - $MESSAGE")
    fi

    # Rotate backups after each directory's backup is completed
    rotate_backups
done

# Send all notifications in a single Gotify message (if enabled)
if [ "$GOTIFY_MESSAGING" = true ]; then
    SUMMARY=$(printf '%s\n' "${NOTIFICATIONS[@]}")
    send_notification "Backup Process Completed" "$SUMMARY" 6
fi

log "Backup process completed."

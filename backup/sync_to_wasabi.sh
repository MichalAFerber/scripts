#!/bin/bash

# ============================================================================
# BLACKBOX TO WASABI CLOUD SYNC SCRIPT
# ============================================================================
# Syncs Blackbox E Red or Blue to Wasabi S3 cloud storage
# Version: 1.0
# ============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Drive paths
RED_DRIVE="/Volumes/Blackbox E Red"
BLUE_DRIVE="/Volumes/Blackbox E Blue"
WASABI_PATH="/Users/michal/Library/CloudStorage/MountainDuck-s3.us-east-1.wasabisys.com–S3/ferber-storage"

# Log directory
LOG_DIR="$HOME/Documents/Logs"
mkdir -p "$LOG_DIR"

# Generate timestamped log filename
TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
LOG_FILE="$LOG_DIR/wasabi_sync_log_$TIMESTAMP.txt"

# ============================================================================
# FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${BLUE}        BLACKBOX TO WASABI CLOUD SYNC${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""
}

check_wasabi() {
    if [ ! -d "$WASABI_PATH" ]; then
        echo -e "${RED}ERROR: Wasabi storage not mounted at:${NC}"
        echo "  $WASABI_PATH"
        echo ""
        echo "Please ensure MountainDuck is running and Wasabi is mounted."
        exit 1
    fi
}

select_source() {
    echo "Which Blackbox drive is the SOURCE (to upload FROM)?"
    echo "  1) Blackbox E Red"
    echo "  2) Blackbox E Blue"
    read -p "Enter choice (1 or 2): " choice

    case $choice in
        1)
            SOURCE="$RED_DRIVE"
            SOURCE_NAME="Red"
            ;;
        2)
            SOURCE="$BLUE_DRIVE"
            SOURCE_NAME="Blue"
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac

    # Check if source drive is mounted
    if [ ! -d "$SOURCE" ]; then
        echo -e "${RED}ERROR: $SOURCE_NAME drive not found at:${NC}"
        echo "  $SOURCE"
        echo ""
        echo "Please connect the drive and try again."
        exit 1
    fi
}

ask_dry_run() {
    read -p "Perform dry-run first (recommended)? (y/n): " dry_run_choice
    case $dry_run_choice in
        [Yy]*)
            DRY_RUN="--dry-run"
            MODE_TEXT="DRY-RUN (no changes will be made)"
            ;;
        [Nn]*)
            DRY_RUN=""
            MODE_TEXT="LIVE SYNC (will upload to Wasabi)"
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
}

ask_progress() {
    read -p "Show overall progress bar? (y/n): " progress_choice
    case $progress_choice in
        [Yy]*)
            PROGRESS_FLAG="--info=progress2"
            ;;
        [Nn]*)
            PROGRESS_FLAG=""
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
}

confirm_sync() {
    echo ""
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${GREEN}SOURCE:      ${NC}$SOURCE"
    echo -e "${GREEN}DESTINATION: ${NC}Wasabi Cloud Storage"
    echo -e "${GREEN}             ${NC}$WASABI_PATH"
    echo -e "${YELLOW}MODE:        ${NC}$MODE_TEXT"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""

    read -p "Proceed with sync? (y/n): " confirm
    case $confirm in
        [Yy]*)
            return 0
            ;;
        *)
            echo "Sync cancelled."
            exit 0
            ;;
    esac
}

perform_sync() {
    echo ""
    echo "---------------------------------------------------"
    echo "Starting Wasabi Sync: $(date)"
    echo "Source: $SOURCE"
    echo "Destination: Wasabi Cloud Storage"
    echo "Log: $LOG_FILE"
    echo "---------------------------------------------------"

    # Start logging
    {
        echo "====================================================="
        echo "BLACKBOX TO WASABI CLOUD SYNC"
        echo "====================================================="
        echo "Start Time: $(date)"
        echo "Source: $SOURCE"
        echo "Destination: $WASABI_PATH"
        echo "Mode: $MODE_TEXT"
        echo "====================================================="
        echo ""
    } > "$LOG_FILE"

    # Run rsync (NO --delete flag to preserve all files in cloud)
    /opt/homebrew/bin/rsync -avh \
        --exclude='.fseventsd' \
        --exclude='.Spotlight-V100' \
        --exclude='.Trashes' \
        --exclude='.TemporaryItems' \
        --exclude='.DS_Store' \
        --no-perms --no-owner --no-group \
        $PROGRESS_FLAG $DRY_RUN \
        "$SOURCE/" "$WASABI_PATH/" 2>&1 | tee -a "$LOG_FILE"

    # Capture rsync exit code
    RSYNC_EXIT=${PIPESTATUS[0]}

    # Log completion
    {
        echo ""
        echo "====================================================="
        echo "End Time: $(date)"
        echo "Exit Code: $RSYNC_EXIT"
        echo "====================================================="
    } >> "$LOG_FILE"

    # Interpret exit code
    echo ""
    echo "---------------------------------------------------"
    if [ $RSYNC_EXIT -eq 0 ]; then
        echo -e "${GREEN}Sync successfully completed on: $(date)${NC}"
    elif [ $RSYNC_EXIT -eq 23 ]; then
        echo -e "${YELLOW}Sync completed with warnings (exit code 23)${NC}"
        echo "  This is normal - some files may have been skipped."
    else
        echo -e "${RED}Sync failed with exit code: $RSYNC_EXIT${NC}"
        echo "  Check the log file for details."
    fi
    echo "---------------------------------------------------"
    echo ""
    echo "Log saved to $LOG_FILE"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

print_header
check_wasabi
select_source
ask_dry_run
ask_progress
confirm_sync
perform_sync

exit 0

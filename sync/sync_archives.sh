#!/bin/bash

# --- CONFIGURATION ---
LOG_DIR="$HOME/Documents/Logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/sync_log_$(date +%Y-%m-%d_%H%M%S).txt"

# --- PARSE COMMAND LINE ARGUMENTS ---
DRY_RUN=""
PROGRESS_FLAG="--info=progress2"
SHOW_PROGRESS=true

for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN="--dry-run"
            shift
            ;;
        --no-progress)
            PROGRESS_FLAG=""
            SHOW_PROGRESS=false
            shift
            ;;
        *)
            ;;
    esac
done

# --- PROMPT FOR SOURCE (DESTINATION IS AUTOMATIC) ---
echo "====================================================="
echo "           BLACKBOX ARCHIVE SYNC"
echo "====================================================="
echo ""
echo "Which drive is the SOURCE (to copy FROM)?"
echo "  1) Blackbox E Red    ->  (will sync TO Blue)"
echo "  2) Blackbox E Blue   ->  (will sync TO Red)"
read -p "Enter choice (1 or 2): " source_choice

# Set paths based on choice - destination is automatic opposite
if [ "$source_choice" == "1" ]; then
    SOURCE="/Volumes/Blackbox E Red"
    DEST="/Volumes/Blackbox E Blue"
elif [ "$source_choice" == "2" ]; then
    SOURCE="/Volumes/Blackbox E Blue"
    DEST="/Volumes/Blackbox E Red"
else
    echo ""
    echo "ERROR: Invalid choice. Please enter 1 or 2."
    exit 1
fi

# --- PROMPT FOR DRY RUN IF NOT PASSED AS ARGUMENT ---
if [ -z "$DRY_RUN" ]; then
    echo ""
    read -p "Perform dry-run first (recommended)? (y/n): " dry_run_choice
    if [ "$dry_run_choice" == "y" ] || [ "$dry_run_choice" == "Y" ]; then
        DRY_RUN="--dry-run"
    fi
fi

# --- PROMPT FOR PROGRESS DISPLAY IF NOT PASSED AS ARGUMENT ---
if [ "$SHOW_PROGRESS" == true ]; then
    echo ""
    read -p "Show overall progress bar? (y/n): " progress_choice
    if [ "$progress_choice" == "n" ] || [ "$progress_choice" == "N" ]; then
        PROGRESS_FLAG=""
    fi
fi

# --- CONFIRMATION ---
echo ""
echo "====================================================="
echo "SOURCE:      $SOURCE"
echo "DESTINATION: $DEST"
if [ -n "$DRY_RUN" ]; then
    echo "MODE:        DRY RUN (no changes will be made)"
else
    echo "MODE:        LIVE SYNC (will modify destination)"
fi
echo "====================================================="
echo ""
read -p "Proceed with sync? (y/n): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Sync cancelled."
    exit 0
fi

# --- EXECUTION ---
echo ""
echo "---------------------------------------------------"
echo "Starting Archive Sync: $(date)"
echo "Source: $SOURCE"
echo "Destination: $DEST"
echo "Log: $LOG_FILE"
if [ -n "$DRY_RUN" ]; then
    echo "DRY RUN MODE - No files will be changed"
fi
echo "---------------------------------------------------"

# Check if both drives are mounted
if [ -d "$SOURCE" ] && [ -d "$DEST" ]; then
    echo "Both drives detected. Starting sync..."
    echo ""

    # Build rsync command with additional flags for better error handling
    # -a: archive, -v: verbose, -h: human-readable, --delete: mirror exactly
    # --exclude: Skip macOS system files and caches
    # --no-perms --no-owner --no-group: Avoid permission conflicts on external drives
    rsync -avh --delete \
        --exclude='.fseventsd' \
        --exclude='.Spotlight-V100' \
        --exclude='.Trashes' \
        --exclude='.TemporaryItems' \
        --exclude='.DS_Store' \
        --no-perms --no-owner --no-group \
        $PROGRESS_FLAG $DRY_RUN \
        "$SOURCE/" "$DEST/" 2>&1 | tee -a "$LOG_FILE"

    # Capture rsync exit code using PIPESTATUS to get rsync's exit code, not tee's
    RSYNC_EXIT=${PIPESTATUS[0]}

    # Log completion
    echo "" | tee -a "$LOG_FILE"
    echo "---------------------------------------------------" | tee -a "$LOG_FILE"
    if [ -n "$DRY_RUN" ]; then
        echo "Dry run completed on: $(date)" | tee -a "$LOG_FILE"
        echo "No files were modified." | tee -a "$LOG_FILE"
    else
        if [ $RSYNC_EXIT -eq 0 ]; then
            echo "Sync successfully completed on: $(date)" | tee -a "$LOG_FILE"
        elif [ $RSYNC_EXIT -eq 23 ]; then
            echo "Sync completed with warnings on: $(date)" | tee -a "$LOG_FILE"
            echo "  Some files could not be transferred (see log for details)" | tee -a "$LOG_FILE"
            echo "  This is usually normal - special files like .gsheet shortcuts were skipped" | tee -a "$LOG_FILE"
        else
            echo "Sync failed with errors on: $(date)" | tee -a "$LOG_FILE"
            echo "  Exit code: $RSYNC_EXIT" | tee -a "$LOG_FILE"
        fi
    fi
    echo "---------------------------------------------------" | tee -a "$LOG_FILE"
    echo ""
    echo "Log saved to $LOG_FILE"

    # Exit with the rsync exit code
    exit $RSYNC_EXIT
else
    echo "ERROR: Ensure both '$SOURCE' and '$DEST' are mounted." | tee -a "$LOG_FILE"
    exit 1
fi

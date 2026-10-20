#!/usr/bin/env bash
#
# Incremental photo backup to AWS S3 Glacier.
#
# Finds photos under PHOTOS_ROOT that have never been backed up before
# (tracked via a manifest file), zips just those, uploads the zip to S3
# under a cold storage class, and records them in the manifest so the
# next run only picks up what's new.
#
# Intended to run quarterly from cron. Safe to run more often or re-run
# after a failure: nothing is marked as backed up until the upload
# succeeds.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- load config from .env -------------------------------------------------

ENV_FILE="$REPO_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

PHOTOS_ROOT="${PHOTOS_ROOT:-$REPO_ROOT/photos}"
AWS_S3_BUCKET="${AWS_S3_BUCKET:?Set AWS_S3_BUCKET in .env}"
AWS_S3_PREFIX="${AWS_S3_PREFIX:-photos}"
GLACIER_STORAGE_CLASS="${GLACIER_STORAGE_CLASS:-DEEP_ARCHIVE}"
BACKUP_STATE_DIR="${BACKUP_STATE_DIR:-$REPO_ROOT/backups/photos-glacier}"

# Resolve PHOTOS_ROOT relative to the repo root the same way docker-compose does.
case "$PHOTOS_ROOT" in
  /*) : ;;
  *) PHOTOS_ROOT="$REPO_ROOT/${PHOTOS_ROOT#./}" ;;
esac

# Source folders to back up, relative to PHOTOS_ROOT (= Immich's
# UPLOAD_LOCATION): originals sorted by the storage template, plus uploads
# not sorted yet. Deliberately excludes Immich's regenerable derivatives
# (thumbs/, encoded-video/, profile/) and its database dumps (backups/).
SOURCE_DIRS=(
  "library"
  "upload"
)

LOG_FILE="$BACKUP_STATE_DIR/backup.log"
MANIFEST_FILE="$BACKUP_STATE_DIR/manifest.txt"
LOCK_FILE="$BACKUP_STATE_DIR/.lock"

mkdir -p "$BACKUP_STATE_DIR"
touch "$MANIFEST_FILE"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    log "Another run is already in progress, exiting."
    exit 1
  fi
else
  log "WARNING: 'flock' not found, skipping overlap protection."
fi

for bin in aws zip; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    log "ERROR: required command '$bin' not found on PATH."
    exit 1
  fi
done

# --- find files not yet backed up -------------------------------------------

CURRENT_LIST="$(mktemp)"
NEW_LIST="$(mktemp)"
trap 'rm -f "$CURRENT_LIST" "$NEW_LIST"' EXIT

: > "$CURRENT_LIST"
for dir in "${SOURCE_DIRS[@]}"; do
  src="$PHOTOS_ROOT/$dir"
  [[ -d "$src" ]] || continue
  find "$src" -type f ! -name '.DS_Store' -print \
    | sed "s|^$PHOTOS_ROOT/||" >> "$CURRENT_LIST"
done
sort -o "$CURRENT_LIST" "$CURRENT_LIST"

comm -23 "$CURRENT_LIST" <(sort "$MANIFEST_FILE") > "$NEW_LIST"

NEW_COUNT="$(wc -l < "$NEW_LIST" | tr -d ' ')"
if [[ "$NEW_COUNT" -eq 0 ]]; then
  log "No new photos since last backup, nothing to do."
  exit 0
fi

# --- zip and upload ----------------------------------------------------------

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
ARCHIVE_NAME="photos-backup-$TIMESTAMP.zip"
ARCHIVE_PATH="$BACKUP_STATE_DIR/$ARCHIVE_NAME"

log "Found $NEW_COUNT new file(s), zipping into $ARCHIVE_NAME..."
(cd "$PHOTOS_ROOT" && zip -X -q -r "$ARCHIVE_PATH" -@ < "$NEW_LIST")

ARCHIVE_SIZE="$(du -h "$ARCHIVE_PATH" | cut -f1)"
log "Archive created ($ARCHIVE_SIZE). Uploading to s3://$AWS_S3_BUCKET/$AWS_S3_PREFIX/$ARCHIVE_NAME (storage class: $GLACIER_STORAGE_CLASS)..."

if aws s3 cp "$ARCHIVE_PATH" "s3://$AWS_S3_BUCKET/$AWS_S3_PREFIX/$ARCHIVE_NAME" \
     --storage-class "$GLACIER_STORAGE_CLASS"; then
  cat "$NEW_LIST" >> "$MANIFEST_FILE"
  sort -u -o "$MANIFEST_FILE" "$MANIFEST_FILE"
  rm -f "$ARCHIVE_PATH"
  log "Upload succeeded, manifest updated ($NEW_COUNT file(s) recorded)."
else
  log "ERROR: upload failed. Archive kept at $ARCHIVE_PATH, manifest NOT updated so next run retries these files."
  exit 1
fi

#!/usr/bin/env bash
#
# Nightly backup of the app configs and the Immich database
# (run by config-backup.timer, every night at 03:30).
#
# Writes two files to the data HDD, so a dead SSD doesn't take them along:
#   /srv/data/backups/config/immich-db-<date>.sql.gz   (pg_dumpall, Immich's
#                                                       recommended way)
#   /srv/data/backups/config/config-<date>.tar.gz      (config/, without
#                                                       caches and logs)
# Only the newest 7 of each are kept.
#
# The apps keep their settings in SQLite files that can't be copied safely
# while they run, so the containers that use config/ are stopped for the
# copy (about a minute) and the ones that were running are started again.
#
# Logs go to the journal: journalctl -u config-backup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST=/srv/data/backups/config
KEEP=7
APPS=(jellyfin sonarr radarr prowlarr bazarr seerr qbittorrent)
STAMP="$(date +%Y-%m-%d_%H%M)"

# /srv/data is mounted with nofail: if the HDD is missing, the folder is
# just an empty directory on the SSD, and we must not fill that.
if ! mountpoint -q /srv/data; then
  echo "FAILED: /srv/data is not mounted (data HDD missing?), no backup made."
  exit 1
fi
mkdir -p "$DEST"

# 1. Immich database, dumped while it runs (pg_dumpall is consistent).
docker exec immich-postgres sh -c 'pg_dumpall --clean --if-exists --username="$POSTGRES_USER"' \
  | gzip > "$DEST/immich-db-$STAMP.sql.gz.part"
mv "$DEST/immich-db-$STAMP.sql.gz.part" "$DEST/immich-db-$STAMP.sql.gz"

# 2. config/, with the apps that write to it stopped.
running=()
for app in "${APPS[@]}"; do
  if [[ "$(docker inspect -f '{{.State.Running}}' "$app" 2>/dev/null)" == "true" ]]; then
    running+=("$app")
  fi
done
restart_apps() {
  if (( ${#running[@]} )); then
    docker start "${running[@]}" > /dev/null
  fi
}
trap restart_apps EXIT
if (( ${#running[@]} )); then
  docker stop "${running[@]}" > /dev/null
fi

tar -C "$REPO_ROOT" -czf "$DEST/config-$STAMP.tar.gz.part" \
  --exclude='config/*/logs' --exclude='config/*/*/logs' --exclude='config/jellyfin/log' \
  --exclude='config/*/cache' --exclude='config/*/.cache' \
  --exclude='config/jellyfin/data/transcodes' \
  config
mv "$DEST/config-$STAMP.tar.gz.part" "$DEST/config-$STAMP.tar.gz"

restart_apps
trap - EXIT

# 3. Keep only the newest $KEEP of each kind.
for kind in immich-db config; do
  ls -1t "$DEST/$kind"-*.gz | tail -n +$((KEEP + 1)) | xargs -r rm --
done

echo "OK: $(du -h "$DEST/immich-db-$STAMP.sql.gz" | cut -f1) database," \
  "$(du -h "$DEST/config-$STAMP.tar.gz" | cut -f1) config, in $DEST"

#!/usr/bin/env bash
#
# Weekly Immich update (run by immich-update.timer, Sundays 04:30).
#
# Pulls the newest Immich server and machine-learning images and restarts
# them. Before that, it compares our database image with the one in
# Immich's official docker-compose.yml for the latest release: if Immich
# now needs a different database, the update is skipped and logged, so
# the app never gets ahead of its database. Fix docker-compose.yaml by
# hand (read the release notes) and the next run picks it up.
#
# Logs go to the journal: journalctl -u immich-update

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OFFICIAL_COMPOSE_URL="https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml"

cd "$REPO_ROOT"

official_db="$(curl -fsSL "$OFFICIAL_COMPOSE_URL" \
  | grep -oE 'ghcr\.io/immich-app/postgres:[^@" ]+' | head -n1)"
ours_db="$(grep -oE 'ghcr\.io/immich-app/postgres:[^@" ]+' docker-compose.yaml | head -n1)"

if [[ -z "$official_db" ]]; then
  echo "Could not read Immich's official compose file, skipping this week."
  exit 1
fi

if [[ "$official_db" != "$ours_db" ]]; then
  echo "SKIPPED: Immich now uses database image '$official_db', we have '$ours_db'."
  echo "Read the Immich release notes and update docker-compose.yaml by hand."
  exit 1
fi

before="$(docker compose images -q immich-server 2>/dev/null || true)"
docker compose pull --quiet immich-server immich-machine-learning immich-redis
docker compose up -d immich-server immich-machine-learning immich-redis
after="$(docker compose images -q immich-server 2>/dev/null || true)"

if [[ "$before" == "$after" ]]; then
  echo "Immich already up to date."
else
  echo "Immich updated and restarted."
fi

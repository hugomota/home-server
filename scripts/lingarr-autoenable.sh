#!/usr/bin/env bash
# Turns on Lingarr's automatic EN -> PT-PT translation as soon as a Lingarr
# release has the "first target only" option (upstream PR #602, 2026-11-05).
#
# Why wait: Lingarr 1.4.1 only checks for an existing "pt-pt" subtitle, so it
# would also translate films that already have Bazarr's ".pt.srt". With
# first_target_only + targets [pt-PT, pt] it translates only when neither
# exists = a real fallback.
#
# Runs daily (lingarr-autoenable.timer). Each run:
#   1. stops if automation is already on (job done) or the media profile is off;
#   2. stops if the latest release is still the pinned one or lacks the option;
#   3. checks DeepL answers (translates one word; never reads the key);
#   4. backs up config/lingarr, bumps the image tag, recreates the container;
#   5. sets targets + first_target_only + automation on, verifies;
#   6. on any failure: restores the old tag + config and recreates it.
set -euo pipefail

REPO_DIR=/home/hmota/projects/home-server
COMPOSE="$REPO_DIR/docker-compose.yaml"
CONFIG="$REPO_DIR/config/lingarr"
GH=https://api.github.com/repos/lingarr-translate/lingarr

log() { echo "lingarr-autoenable: $*"; }

api() { # api <method> <path> [json]
  local ip
  ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lingarr)
  if [ $# -ge 3 ]; then
    curl -sf -m 60 -X "$1" "http://$ip:9876$2" -H 'Content-Type: application/json' -d "$3"
  else
    curl -sf -m 60 -X "$1" "http://$ip:9876$2"
  fi
}

wait_up() {
  for _ in $(seq 1 30); do
    api GET /api/version >/dev/null 2>&1 && return 0
    sleep 3
  done
  return 1
}

if [ "$(docker inspect -f '{{.State.Running}}' lingarr 2>/dev/null)" != "true" ]; then
  log "lingarr not running (media profile off?), nothing to do"; exit 0
fi

if [ "$(api GET /api/setting/automation_enabled || true)" = "true" ]; then
  log "automation already on, nothing to do"; exit 0
fi

current=$(grep -oP 'ghcr.io/lingarr-translate/lingarr:\K[0-9.]+' "$COMPOSE")
latest=$(curl -sf -m 30 "$GH/releases/latest" | python3 -c 'import sys,json;print(json.load(sys.stdin)["tag_name"].lstrip("v"))')
log "pinned $current, latest release $latest"

if [ "$latest" = "$current" ] || [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -1)" != "$latest" ]; then
  log "no newer release yet"; exit 0
fi

if ! curl -sf -m 30 -H 'Accept: application/vnd.github.raw' \
     "$GH/contents/Lingarr.Core/Configuration/SettingKeys.cs?ref=$latest" | grep -q first_target_only; then
  log "release $latest has no first_target_only yet, waiting"; exit 0
fi

word=$(api POST /api/translate/line '{"subtitleLine":"Good morning","sourceLanguage":"en","targetLanguage":"pt-PT"}' || true)
if [ -z "$word" ] || [ "$word" = "Good morning" ]; then
  log "DeepL test translation failed (key missing or quota used up?), not upgrading"; exit 1
fi

backup="$REPO_DIR/config/lingarr-before-$latest.tar.gz"
log "backing up config to $backup"
tar -czf "$backup" -C "$REPO_DIR/config" lingarr

rollback() {
  log "FAILED, rolling back to $current"
  sed -i "s|ghcr.io/lingarr-translate/lingarr:$latest|ghcr.io/lingarr-translate/lingarr:$current|" "$COMPOSE"
  docker stop lingarr >/dev/null 2>&1 || true
  rm -rf "$CONFIG" && tar -xzf "$backup" -C "$REPO_DIR/config"
  (cd "$REPO_DIR" && docker compose --profile media up -d lingarr)
  exit 1
}
trap rollback ERR

sed -i "s|ghcr.io/lingarr-translate/lingarr:$current|ghcr.io/lingarr-translate/lingarr:$latest|" "$COMPOSE"
(cd "$REPO_DIR" && docker compose --profile media pull -q lingarr && docker compose --profile media up -d lingarr)
wait_up

running=$(api GET /api/version | python3 -c 'import sys,json;print(json.load(sys.stdin)["currentVersion"])')
[ "$running" = "$latest" ]

# The setting row may not exist yet in an upgraded DB: try multiple/set, then single set.
api POST /api/setting/multiple/set \
  '{"target_languages":"[{\"name\":\"Portuguese (Portugal)\",\"code\":\"pt-PT\"},{\"name\":\"Portuguese\",\"code\":\"pt\"}]"}' >/dev/null
api POST /api/setting/multiple/set '{"first_target_only":"true"}' >/dev/null \
  || api POST /api/setting '{"key":"first_target_only","value":"true"}' >/dev/null
[ "$(api GET /api/setting/first_target_only)" = "true" ]

# Sonarr/Radarr still reachable after the upgrade?
api GET /api/schedule/job/movie >/dev/null
sleep 20
docker logs lingarr --since 1m 2>&1 | grep -q "Synced and saved"

api POST /api/setting/multiple/set '{"automation_enabled":"true"}' >/dev/null
[ "$(api GET /api/setting/automation_enabled)" = "true" ]

trap - ERR
date '+%Y-%m-%d %H:%M' > "$REPO_DIR/config/lingarr-autoenable.done"   # shown by server-status
log "DONE: Lingarr $latest, targets [pt-PT, pt], first_target_only on, automation on (04:00, max 5/run)"

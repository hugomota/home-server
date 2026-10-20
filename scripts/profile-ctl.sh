#!/usr/bin/env bash
#
# Start or stop one Docker Compose profile (media, ai) without touching
# the always-on core services.
#
# Usage:  profile-ctl.sh <profile> <on|off>
#    or through the shortcuts linked in /usr/local/bin, whose name says
#    what to do:  media-on, media-off, ai-on, ai-off
#
# Note: `docker compose --profile X stop` would also stop the core
# services, so "off" stops only the services that belong to the profile.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Called as a shortcut (e.g. media-on): take profile and action from the name.
name="$(basename "$0")"
if [[ "$name" == *-on || "$name" == *-off ]]; then
  PROFILE="${name%-*}"
  ACTION="${name##*-}"
else
  PROFILE="${1:?Usage: $name <profile> <on|off>}"
  ACTION="${2:?Usage: $name <profile> <on|off>}"
fi

cd "$REPO_ROOT"

core_services="$(docker compose config --services | sort)"
profile_services="$(comm -13 <(echo "$core_services") \
  <(docker compose --profile "$PROFILE" config --services | sort))"

if [[ -z "$profile_services" ]]; then
  echo "Unknown profile '$PROFILE' (no services found)." >&2
  exit 1
fi

case "$ACTION" in
  on)
    echo "Starting $PROFILE: $(echo $profile_services)"
    # shellcheck disable=SC2086
    docker compose --profile "$PROFILE" up -d $profile_services
    ;;
  off)
    echo "Stopping $PROFILE: $(echo $profile_services)"
    # shellcheck disable=SC2086
    docker compose --profile "$PROFILE" stop $profile_services
    ;;
  *)
    echo "Action must be 'on' or 'off', got '$ACTION'." >&2
    exit 1
    ;;
esac

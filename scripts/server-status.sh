#!/usr/bin/env bash
#
# One-screen overview of the server: uptime, memory, disks, CPU temperature,
# containers, last nightly backup and anything that needs attention.
# Read-only and needs no sudo. Doesn't wake the data HDD (df only reads
# cached filesystem info).
#
# Usage:  server-status   (shortcut linked in /usr/local/bin)

set -uo pipefail

bold=$'\e[1m'; red=$'\e[31m'; yellow=$'\e[33m'; green=$'\e[32m'; reset=$'\e[0m'
[[ -t 1 ]] || { bold=; red=; yellow=; green=; reset=; }

# Colour a percentage: green below 80, yellow from 80, red from 90.
pct_colour() {
    if (( $1 >= 90 )); then echo "$red"; elif (( $1 >= 80 )); then echo "$yellow"; else echo "$green"; fi
}

echo "${bold}$(hostname) — $(date '+%a %d %b %H:%M')${reset}"
echo "Up $(uptime -p | sed 's/^up //'), load $(cut -d' ' -f1-3 /proc/loadavg)"

# CPU package temperature from the coretemp sensor.
for hw in /sys/class/hwmon/hwmon*; do
    if [[ "$(cat "$hw/name" 2>/dev/null)" == coretemp ]]; then
        echo "CPU $(( $(cat "$hw/temp1_input") / 1000 )) °C"
    fi
done

echo
echo "${bold}Memory${reset}"
free -h | awk 'NR==2 {print "  RAM  " $3 " used of " $2 ", " $7 " available"}
               NR==3 {print "  Swap " $3 " used of " $2}'

echo
echo "${bold}Disks${reset}"
for mount in / /srv/data; do
    if ! mountpoint -q "$mount"; then
        echo "  ${red}$mount is NOT mounted${reset}"
        continue
    fi
    read -r size used avail pct < <(df -h --output=size,used,avail,pcent "$mount" | tail -1)
    p=${pct%\%}
    printf '  %-10s %s%4s%s used  (%s of %s, %s free)\n' \
        "$mount" "$(pct_colour "$p")" "$pct" "$reset" "$used" "$size" "$avail"
done

echo
echo "${bold}Containers${reset}"
if docker info >/dev/null 2>&1; then
    running=$(docker ps -q | wc -l)
    echo "  $running running"
    docker ps --filter health=unhealthy --format '  '"$red"'unhealthy: {{.Names}}'"$reset"
    docker ps -a --filter status=exited --filter status=dead --format '{{.Names}} {{.Status}}' |
        grep -v 'Exited (0)' | sed "s/^/  ${yellow}stopped with error: /; s/\$/${reset}/"
else
    echo "  ${yellow}can't reach Docker${reset}"
fi

echo
echo "${bold}Nightly backup${reset}"
result=$(systemctl show config-backup.service -p Result --value)
last=$(systemctl show config-backup.service -p ExecMainExitTimestamp --value)
if [[ -z "$last" ]]; then
    echo "  hasn't run yet"
elif [[ "$result" == success ]]; then
    echo "  ${green}OK${reset} — $last"
else
    echo "  ${red}FAILED ($result)${reset} — $last  (journalctl -u config-backup)"
fi

# Things that need a look.
warnings=()
failed=$(systemctl --failed --no-legend --plain | awk '{print $1}' | paste -sd' ')
[[ -n "$failed" ]] && warnings+=("failed services: $failed")
[[ -f /run/reboot-required ]] && warnings+=("reboot needed (will happen at 04:00 automatically)")
# Written by scripts/lingarr-autoenable.sh once it has done its job.
lingarr_done=/home/hmota/projects/home-server/config/lingarr-autoenable.done
[[ -f "$lingarr_done" ]] && systemctl is-enabled -q lingarr-autoenable.timer 2>/dev/null \
    && warnings+=("Lingarr auto-translation is ON since $(cat "$lingarr_done"): remove the timer (readme: Lingarr)")
if (( ${#warnings[@]} )); then
    echo
    echo "${bold}Attention${reset}"
    printf "  ${yellow}%s${reset}\n" "${warnings[@]}"
fi

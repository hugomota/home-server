#!/usr/bin/env bash
# Rename Lingarr's European Portuguese subtitles from <name>.pt-pt.srt to
# <name>.pt.srt so Jellyfin recognises them as Portuguese ("por").
# Jellyfin keeps "pt-pt" as an unknown language, so the user's preferred
# subtitle language never picks those files.
# Never overwrites: if <name>.pt.srt already exists (e.g. from Bazarr),
# the .pt-pt.srt file is left alone.
set -euo pipefail

MEDIA=/srv/data/media

if ! mountpoint -q /srv/data; then
  echo "/srv/data is not mounted, skipping"
  exit 0
fi

renamed=0
skipped=0
while IFS= read -r -d '' f; do
  target="${f%.[pP][tT]-[pP][tT].srt}.pt.srt"
  if [ -e "$target" ]; then
    skipped=$((skipped + 1))
    echo "kept (a .pt.srt already exists): $f"
    continue
  fi
  mv -n -- "$f" "$target"
  renamed=$((renamed + 1))
  echo "renamed: $target"
done < <(find "$MEDIA/movies" "$MEDIA/tv" -type f -iname '*.pt-pt.srt' -print0)

echo "done: $renamed renamed, $skipped kept"

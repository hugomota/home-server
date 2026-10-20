# Home Server Stack

This project ships a broader Docker Compose setup for a real home server:

- Media streaming with Jellyfin
- Movie/TV automation with Radarr, Sonarr, Prowlarr, Bazarr, and Jellyseerr
- Torrents with qBittorrent
- Photo hosting with Immich
- Dashboard with Homepage
- Existing extras kept in place: Traefik, Ollama, Open WebUI, and SearXNG

## Included Services

| Service | Port | Access URL | Purpose |
|---|---:|---|---|
| Homepage | 3000 | `https://home.<your-domain>` or `http://localhost:3000` | Main dashboard |
| Traefik | 80, 443, 8088 | `https://traefik.<your-domain>` | Reverse proxy and dashboard |
| Ollama | 11434 | `https://ollama.<your-domain>` or `http://localhost:11434` | Local LLM runtime and model API |
| Open WebUI | proxied | `https://openwebui.<your-domain>` | Local AI UI |
| SearXNG | 8080 | `http://localhost:8080` | Metasearch backend |
| Jellyfin | 8096 | `http://<server-ip>:8096` (TV/Android apps) or `https://jellyfin.<your-domain>` | Media server |
| Jellyseerr | 5055 | `https://request.<your-domain>` or `http://localhost:5055` | Media request portal |
| qBittorrent | 8081, 6881 | `https://torrent.<your-domain>` or `http://localhost:8081` | Torrent client |
| Prowlarr | 9696 | `https://indexers.<your-domain>` or `http://localhost:9696` | Indexer management |
| Sonarr | 8989 | `https://sonarr.<your-domain>` or `http://localhost:8989` | TV automation |
| Radarr | 7878 | `https://radarr.<your-domain>` or `http://localhost:7878` | Movie automation |
| Bazarr | 6767 | `https://subtitles.<your-domain>` or `http://localhost:6767` | Subtitle automation |
| Immich | 2283 | `https://photos.<your-domain>` or `http://localhost:2283` | Photo and image manager |

## Folder Layout

Create these folders before first boot if they do not exist yet:

```text
config/
data/
downloads/
media/
media/movies/
media/tv/
photos/
photos/library/
photos/icloud/
```

## Quick Start

1. Copy [.env.example](/Users/mothug01/Projects/home-server/.env.example) to `.env`.
2. Set `PUID`, `PGID`, `TZ`, `DOMAIN`, and `DB_PASSWORD`.
3. Start the stack:

```bash
docker compose up -d
```

   This starts only the core services (Traefik, Homepage, Immich, Jellyfin). The rest are grouped in profiles and start only when asked:

   | Profile | Services |
   |---|---|
   | `media` | Jellyseerr, qBittorrent, FlareSolverr, Prowlarr, Sonarr, Radarr, Bazarr |
   | `ai` | Ollama, Open WebUI, SearXNG |

   ```bash
   docker compose --profile media up -d      # start a group
   docker compose --profile media stop       # stop it again
   ```

   Running services come back after a reboot (`restart: unless-stopped`); stopped ones stay stopped.

4. Add local host entries for the `local.server` names pointing to this server. Wildcards do not work in `/etc/hosts`, so add the explicit hostnames you need.
5. Open the dashboard at `https://home.<your-domain>` or `http://<server-ip>:3000`, then continue the first-run setup for the apps you want.

## Local HTTPS

This stack is configured for trusted local HTTPS with `mkcert`.

Trusted certificate setup:

```bash
mkcert -install
cd config/traefik/certs
mkcert -cert-file local-server.crt -key-file local-server.key local.server '*.local.server'
```

Local hostname setup on macOS/Linux:

```bash
echo '127.0.0.1 home.local.server traefik.local.server openwebui.local.server jellyfin.local.server request.local.server torrent.local.server indexers.local.server sonarr.local.server radarr.local.server subtitles.local.server photos.local.server' | sudo tee -a /etc/hosts
```

Once those are in place, the HTTPS routes should resolve locally without the usual browser certificate warning on this machine.

## Recommended Setup Order

1. Open qBittorrent and set download categories and folders inside `/downloads`.
2. Open Prowlarr and add your indexers.
3. Connect Prowlarr to Sonarr and Radarr.
4. In Sonarr and Radarr, add qBittorrent as the download client and point root folders to `/tv` and `/movies`.
5. In Bazarr, connect Sonarr and Radarr and choose subtitle languages/providers.
6. In Jellyfin, add libraries from `/media/movies` and `/media/tv`.
7. In Jellyseerr, connect Jellyfin plus Sonarr/Radarr so requests can flow automatically.
8. In Immich, create the first admin user and start uploading photos.
9. In Immich, add `photos/icloud` as an external library if you want the existing iCloud photos there to appear.
10. Open WebUI at `https://openwebui.<your-domain>` and use the connected Ollama backend for local models.
11. Pull models into Ollama with commands like `docker compose exec -T ollama ollama pull llama3.2`, `docker compose exec -T ollama ollama pull qwen2.5:7b`, or `docker compose exec -T ollama ollama pull mistral`.
12. Use either the secure `https://<service>.<your-domain>` routes or the direct host ports, whichever is more convenient for your device.

## Watching on a TV / Android Box

Jellyfin has two parts:

- **Jellyfin server**: the `jellyfin` container on this host. It keeps the library and streams the video. It is always on (no profile).
- **Jellyfin app**: installed on the device you watch on. It is only the screen and remote; nothing else is needed on the server to watch.

On an Android TV box, install **"Jellyfin for Android TV"** from the Play Store and enter the server as `http://<server-ip>:8096` (here: `http://192.168.1.50:8096`). The app remembers it.

Why the IP and port instead of `https://jellyfin.<your-domain>`:

- Traefik only routes a request once it reaches the server. Turning `jellyfin.local.server` into `192.168.1.50` is a DNS job, and today that only works on devices where the name was added to `/etc/hosts` by hand. Android boxes, phones and TVs can't do that.
- The HTTPS certificate comes from `mkcert`, which those devices don't trust, so the Jellyfin app may refuse to connect.
- A local DNS server (e.g. AdGuard Home) could serve `*.local.server` to the whole network, but the router must point to it, home internet breaks when the server is down, and the certificate problem stays. Not worth it for now.

Port `8096` is published only on the home network; it is not reachable from the internet unless a port is forwarded on the router.

The Mac mini's Ivy Bridge GPU can't hardware-transcode HEVC/4K, so playback relies on the box playing files directly (most Android boxes do). If a file stutters, it is probably being transcoded on the CPU.

### Jellyfin vs Jellyseerr

- **Jellyfin** plays what is already on the server.
- **Jellyseerr** is a request page for things you don't have yet. It doesn't play or download anything itself; it passes the request along:

```
Jellyseerr  ->  Radarr (movies) / Sonarr (series)  ->  Prowlarr finds it  ->  qBittorrent downloads it  ->  shows up in Jellyfin
```

That is why Jellyfin is always on, while Jellyseerr sits in the `media` profile with the downloaders: start the profile to request something, stop it when the download is done.

## Photo Backup to AWS S3 Glacier

`scripts/photos-glacier-backup.sh` does an incremental cold-storage backup of `photos/icloud` and Immich's original assets (`photos/library/library`, `photos/library/upload` — thumbnails and transcodes are skipped since they're regenerable). It tracks what's already been backed up in `backups/photos-glacier/manifest.txt`, so each run only zips and uploads files it hasn't seen before. Nothing is marked as done until the S3 upload succeeds, so a failed run is safe to retry.

Setup:

1. Create an S3 bucket for backups (any region close to you).
2. Create an IAM user with a policy scoped to just that bucket, e.g.:

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": ["s3:PutObject", "s3:ListBucket"],
         "Resource": [
           "arn:aws:s3:::your-glacier-backup-bucket",
           "arn:aws:s3:::your-glacier-backup-bucket/*"
         ]
       }
     ]
   }
   ```

3. Set `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, and `AWS_S3_BUCKET` in `.env`. `GLACIER_STORAGE_CLASS` defaults to `DEEP_ARCHIVE` (cheapest, slow to restore); use `GLACIER` for faster restores at a bit more cost.
4. Install the AWS CLI and `zip` on the host running cron (not inside a container).
5. Run it once by hand to confirm it works: `./scripts/photos-glacier-backup.sh`
6. Schedule it quarterly with cron (`crontab -e` on the host):

   ```cron
   0 3 1 1,4,7,10 * cd /path/to/home-server && ./scripts/photos-glacier-backup.sh >> backups/photos-glacier/cron.log 2>&1
   ```

No extra Docker service is needed — the script and a host cron entry are enough.

## Traefik Hostnames

If `DOMAIN=local.server`, these URLs will work once local DNS or host entries are set:

- `https://home.local.server`
- `https://traefik.local.server`
- `https://ollama.local.server`
- `https://openwebui.local.server`
- `https://jellyfin.local.server`
- `https://request.local.server`
- `https://torrent.local.server`
- `https://indexers.local.server`
- `https://sonarr.local.server`
- `https://radarr.local.server`
- `https://subtitles.local.server`
- `https://photos.local.server`

You can also use the direct host ports listed above without Traefik.

Recommended local entrypoints:

- `https://home.local.server`
- `https://traefik.local.server`

For the Traefik UI specifically:

- `https://traefik.<your-domain>`

## Notes

- The secure `https://<service>.<your-domain>` hostnames work directly through Traefik right now without an extra SSO layer.
- Open WebUI is configured to talk to the local Ollama service at `http://ollama:11434`, so any model that Ollama supports can be used there after you pull it.
- `/etc/hosts` does not support wildcard entries, so each `*.local.server` hostname must be listed explicitly unless you run your own local DNS.
- The Traefik certificate is generated with `mkcert`, which removes browser trust warnings on devices where the mkcert local CA has been installed.
- Sonarr is pinned to `4.0.15.2941-ls295` instead of `latest` because the newer image stream triggered a broken authorization pipeline in this stack.
- qBittorrent is included without a VPN container so the setup stays simple. If you want, we can add Gluetun later.
- Immich is one of the heavier services in the stack. Give the host enough RAM before enabling everything together.
- I could not complete a Moneypile install because the public image reference currently advertised on its website did not resolve when pulled from Docker. If they publish a working public image or repo, I can swap it in quickly.

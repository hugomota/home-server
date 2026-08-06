# Home Server Stack

This project ships a broader Docker Compose setup for a real home server:

- Media streaming with Jellyfin
- Movie/TV automation with Radarr, Sonarr, Prowlarr, Bazarr, and Jellyseerr
- Torrents with qBittorrent
- Photo hosting with Immich and iCloud photo downloads with iCloudPD
- Budgeting with Actual Budget
- Admin and dashboard tools with Portainer, Homepage, File Browser, and Uptime Kuma
- Smart home control with Home Assistant
- Existing extras kept in place: Traefik, Ollama, Open WebUI, and SearXNG

## Included Services

| Service | Port | Access URL | Purpose |
|---|---:|---|---|
| Homepage | 3000 | `https://home.<your-domain>` or `http://localhost:3000` | Main dashboard |
| Portainer | 9000, 9443 | `https://portainer.<your-domain>` or `http://localhost:9000` | Docker management |
| Uptime Kuma | 3001 | `https://status.<your-domain>` or `http://localhost:3001` | Service monitoring |
| File Browser | 8082 | `https://files.<your-domain>` or `http://localhost:8082` | Browse media/download folders |
| Traefik | 80, 443, 8088 | `https://traefik.<your-domain>` | Reverse proxy and dashboard |
| Actual Budget | 5006 | `https://budget.<your-domain>` or `http://localhost:5006` | Budgeting |
| Ollama | 11434 | `https://ollama.<your-domain>` or `http://localhost:11434` | Local LLM runtime and model API |
| Open WebUI | proxied | `https://openwebui.<your-domain>` | Local AI UI |
| SearXNG | 8080 | `http://localhost:8080` | Metasearch backend |
| Jellyfin | 8096, 8920 | `https://jellyfin.<your-domain>` or `http://localhost:8096` | Media server |
| Jellyseerr | 5055 | `https://request.<your-domain>` or `http://localhost:5055` | Media request portal |
| qBittorrent | 8081, 6881 | `https://torrent.<your-domain>` or `http://localhost:8081` | Torrent client |
| Prowlarr | 9696 | `https://indexers.<your-domain>` or `http://localhost:9696` | Indexer management |
| Sonarr | 8989 | `https://sonarr.<your-domain>` or `http://localhost:8989` | TV automation |
| Radarr | 7878 | `https://radarr.<your-domain>` or `http://localhost:7878` | Movie automation |
| Bazarr | 6767 | `https://subtitles.<your-domain>` or `http://localhost:6767` | Subtitle automation |
| Immich | 2283 | `https://photos.<your-domain>` or `http://localhost:2283` | Photo and image manager |
| iCloudPD | none | Background service | Download iCloud photos into `photos/icloud` |
| Home Assistant | 8123 | `https://ha.<your-domain>` or `http://localhost:8123` | Smart home hub |

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
config/icloudpd/
```

## Quick Start

1. Copy [.env.example](/Users/mothug01/Projects/home-server/.env.example) to `.env`.
2. Set `PUID`, `PGID`, `TZ`, `DOMAIN`, `DB_PASSWORD`, and `ICLOUDPD_USERNAME`.
3. Start the stack:

```bash
docker compose up -d
```

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
echo '127.0.0.1 home.local.server traefik.local.server portainer.local.server status.local.server files.local.server budget.local.server openwebui.local.server jellyfin.local.server request.local.server torrent.local.server indexers.local.server sonarr.local.server radarr.local.server subtitles.local.server photos.local.server ha.local.server' | sudo tee -a /etc/hosts
```

Once those are in place, the HTTPS routes should resolve locally without the usual browser certificate warning on this machine.

## Recommended Setup Order

1. Open Portainer and finish the first-run admin setup immediately so it does not time out its setup screen.
2. Open qBittorrent and set download categories and folders inside `/downloads`.
3. Open Prowlarr and add your indexers.
4. Connect Prowlarr to Sonarr and Radarr.
5. In Sonarr and Radarr, add qBittorrent as the download client and point root folders to `/tv` and `/movies`.
6. In Bazarr, connect Sonarr and Radarr and choose subtitle languages/providers.
7. In Jellyfin, add libraries from `/media/movies` and `/media/tv`.
8. In Jellyseerr, connect Jellyfin plus Sonarr/Radarr so requests can flow automatically.
9. Open Actual Budget on `http://<server-ip>:5006` and complete its first-run setup.
10. In Immich, create the first admin user and start uploading photos.
11. Set `ICLOUDPD_USERNAME` in `.env`, then complete the one-time iCloud authentication described below.
12. In Immich, add `photos/icloud` as an external library if you want downloaded iCloud photos to appear there.
13. Open WebUI at `https://openwebui.<your-domain>` and use the connected Ollama backend for local models.
14. Pull models into Ollama with commands like `docker compose exec -T ollama ollama pull llama3.2`, `docker compose exec -T ollama ollama pull qwen2.5:7b`, or `docker compose exec -T ollama ollama pull mistral`.
15. Use either the secure `https://<service>.<your-domain>` routes or the direct host ports, whichever is more convenient for your device.

## iCloud Photos Downloader

iCloudPD runs in the background, checks iCloud at the interval configured by `ICLOUDPD_INTERVAL`, and stores downloads under `photos/icloud`. It deliberately does not mirror deletions from iCloud.

Before starting the background service for the first time, authenticate interactively:

```bash
docker compose run --rm icloudpd icloudpd \
  --directory /data \
  --username "$(sed -n 's/^ICLOUDPD_USERNAME=//p' .env)" \
  --cookie-directory /config
```

Follow the Apple sign-in and two-factor authentication prompts, then start the service:

```bash
docker compose up -d icloudpd
```

Apple periodically requires two-factor reauthentication. Run the interactive command again when the iCloudPD logs report an expired session.

## Traefik Hostnames

If `DOMAIN=local.server`, these URLs will work once local DNS or host entries are set:

- `https://home.local.server`
- `https://traefik.local.server`
- `https://portainer.local.server`
- `https://status.local.server`
- `https://files.local.server`
- `https://budget.local.server`
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
- `https://ha.local.server`

You can also use the direct host ports listed above without Traefik.

Recommended local entrypoints:

- `https://home.local.server`
- `https://traefik.local.server`

For the Traefik UI specifically:

- `https://traefik.<your-domain>`

## Notes

- Home Assistant now publishes `8123` directly, which works better on Docker Desktop and non-Linux hosts. USB radios and LAN discovery are still better on a real Linux machine.
- The secure `https://<service>.<your-domain>` hostnames work directly through Traefik right now without an extra SSO layer.
- Open WebUI is configured to talk to the local Ollama service at `http://ollama:11434`, so any model that Ollama supports can be used there after you pull it.
- `/etc/hosts` does not support wildcard entries, so each `*.local.server` hostname must be listed explicitly unless you run your own local DNS.
- The Traefik certificate is generated with `mkcert`, which removes browser trust warnings on devices where the mkcert local CA has been installed.
- Portainer may disable its first-run page if you leave it idle too long before creating the admin user. If that happens, restart just the Portainer service and open it again right away.
- Sonarr is pinned to `4.0.15.2941-ls295` instead of `latest` because the newer image stream triggered a broken authorization pipeline in this stack.
- qBittorrent is included without a VPN container so the setup stays simple. If you want, we can add Gluetun later.
- Immich is one of the heavier services in the stack. Give the host enough RAM before enabling everything together.
- I could not complete a Moneypile install because the public image reference currently advertised on its website did not resolve when pulled from Docker. If they publish a working public image or repo, I can swap it in quickly.

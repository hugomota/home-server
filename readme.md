# Home Server Stack

This project ships a broader Docker Compose setup for a real home server:

- Media streaming with Jellyfin
- Movie/TV automation with Radarr, Sonarr, Prowlarr, Bazarr, and Jellyseerr
- Torrents with qBittorrent
- Arcade gaming in the browser with EmulatorJS and RomM
- Photo hosting and image management with Immich
- Admin and dashboard tools with Portainer, Homepage, File Browser, and Uptime Kuma
- Smart home control with Home Assistant
- Existing extras kept in place: Traefik, Actual Budget, Open WebUI, and SearXNG

## Included Services

| Service | Port | Purpose |
|---|---:|---|
| Homepage | 3000 | Main dashboard |
| Portainer | 9000, 9443 | Docker management |
| Uptime Kuma | 3001 | Service monitoring |
| File Browser | 8082 | Browse media/download folders |
| Traefik | 80, 8088 | Reverse proxy and dashboard |
| Actual Budget | proxied | Budgeting |
| Open WebUI | proxied | Local AI UI |
| SearXNG | 8080 | Metasearch backend |
| Jellyfin | 8096, 8920 | Media server |
| Jellyseerr | 5055 | Media request portal |
| qBittorrent | 8081, 6881 | Torrent client |
| Prowlarr | 9696 | Indexer management |
| Sonarr | 8989 | TV automation |
| Radarr | 7878 | Movie automation |
| Bazarr | 6767 | Subtitle automation |
| EmulatorJS | 8085, 3003, 4001 | Browser-based retro arcade for your TV |
| RomM | 8086 | Manage your own ROM collection |
| Immich | 2283 | Photo and image manager |
| Home Assistant | 8123 | Smart home hub |

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
data/roms/library/
data/roms/library/roms/
data/roms/library/bios/
```

Useful game-library paths:

```text
data/emulatorjs/
data/emulatorjs/bios/
data/roms/library/
data/roms/library/README.txt
data/roms/library/roms/nes/
data/roms/library/roms/snes/
data/roms/library/roms/n64/
data/roms/library/roms/gba/
data/roms/library/bios/psx/
```

## Quick Start

1. Copy [.env.example](/Users/mothug01/Projects/home-server/.env.example) to `.env`.
2. Set `PUID`, `PGID`, `TZ`, `DOMAIN`, `DB_PASSWORD`, `ROMM_DB_PASSWORD`, `ROMM_DB_ROOT_PASSWORD`, and `ROMM_AUTH_SECRET_KEY`.
3. Start the stack:

```bash
docker compose up -d
```

4. Open the dashboard at `http://<server-ip>:3000`.

## Recommended Setup Order

1. Open Portainer and finish the first-run admin setup immediately so it does not time out its setup screen.
2. Open qBittorrent and set download categories and folders inside `/downloads`.
3. Open Prowlarr and add your indexers.
4. Connect Prowlarr to Sonarr and Radarr.
5. In Sonarr and Radarr, add qBittorrent as the download client and point root folders to `/tv` and `/movies`.
6. In Bazarr, connect Sonarr and Radarr and choose subtitle languages/providers.
7. In Jellyfin, add libraries from `/media/movies` and `/media/tv`.
8. In Jellyseerr, connect Jellyfin plus Sonarr/Radarr so requests can flow automatically.
9. In Immich, create the first admin user and start uploading photos.
10. Open RomM on `http://<server-ip>:8086` and use the shared library mounted at `/romm/library`.
11. Put your own ROMs into `data/roms/library/roms/<platform>/`.
12. EmulatorJS reads the same shared ROM library and serves it to your TV browser on `http://<server-ip>:8085`.

## TV Gaming

For a Mario-style retro setup, start with these folders:

- `data/roms/library/roms/nes/`
- `data/roms/library/roms/snes/`
- `data/roms/library/roms/n64/`
- `data/roms/library/roms/gba/`
- `data/roms/library/roms/gb/`
- `data/roms/library/roms/gbc/`

If a console needs BIOS files, place them under `data/roms/library/bios/<platform>/`.

Recommended flow:

1. Manage the library in RomM at `http://<server-ip>:8086`
2. Open EmulatorJS at `http://<server-ip>:8085`
3. Use a Bluetooth or USB controller paired to the TV/browser device

## Traefik Hostnames

If `DOMAIN=home.arpa`, these URLs will work once local DNS or host entries are set:

- `http://home.home.arpa`
- `http://traefik.home.arpa`
- `http://portainer.home.arpa`
- `http://status.home.arpa`
- `http://files.home.arpa`
- `http://budget.home.arpa`
- `http://openwebui.home.arpa`
- `http://jellyfin.home.arpa`
- `http://request.home.arpa`
- `http://torrent.home.arpa`
- `http://indexers.home.arpa`
- `http://sonarr.home.arpa`
- `http://radarr.home.arpa`
- `http://subtitles.home.arpa`
- `http://photos.home.arpa`
- `http://arcade.home.arpa`
- `http://roms.home.arpa`
- `http://ha.home.arpa`

You can also use the direct host ports listed above without Traefik.

## Notes

- Home Assistant now publishes `8123` directly, which works better on Docker Desktop and non-Linux hosts. USB radios and LAN discovery are still better on a real Linux machine.
- Portainer may disable its first-run page if you leave it idle too long before creating the admin user. If that happens, restart just the Portainer service and open it again right away.
- qBittorrent is included without a VPN container so the setup stays simple. If you want, we can add Gluetun later.
- Immich is one of the heavier services in the stack. Give the host enough RAM before enabling everything together.
- I can help you manage and serve ROMs you legally own, but I can’t set up a service to download copyrighted game files.

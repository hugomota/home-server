# Home Server

Docker Compose stack for a home server on a **Mac mini Late 2012** running
Ubuntu Server: photos (Immich), movies/series (Jellyfin + download
automation) and optional local AI. Server: `192.168.1.50` (`ssh homeserver`).

## Services

A plain `docker compose up -d` starts only the **core** services. The others
are grouped in profiles and start only when asked.

| Profile | Service | Address | Purpose |
|---|---|---|---|
| core | Immich | `http://192.168.1.50:2283` / `https://photos.local.server` | Photos and videos (server + ML + Postgres + Valkey) |
| core | Jellyfin | `http://192.168.1.50:8096` / `https://jellyfin.local.server` | Plays movies and series |
| core | Homepage | `https://home.local.server` | Dashboard with links and status |
| core | Traefik | `https://traefik.local.server` | Reverse proxy for the `*.local.server` names |
| `media` | Seerr | `https://request.local.server` | Request page for new movies/series |
| `media` | Radarr / Sonarr | `https://radarr.local.server` / `https://sonarr.local.server` | Movie / series automation |
| `media` | Prowlarr + FlareSolverr | `https://indexers.local.server` | Indexers (FlareSolverr is internal) |
| `media` | qBittorrent | `https://torrent.local.server` (torrent port 6881) | Downloads |
| `media` | Bazarr | `https://subtitles.local.server` | Subtitles |
| `ai` | Open WebUI + Ollama | `https://openwebui.local.server` / `https://ollama.local.server` | Local AI chat and models |
| `ai` | SearXNG | `https://search.local.server` | Web search for Open WebUI |

### Starting and stopping groups

```bash
media-on     media-off
ai-on        ai-off
```

From the laptop: `ssh homeserver media-on`. The shortcuts run
`scripts/profile-ctl.sh` (linked into `/usr/local/bin`). Don't use
`docker compose --profile media stop`: it stops the core services too; the
script stops only the profile's own services.

Running services come back after a reboot (`restart: unless-stopped`);
stopped ones stay stopped.

### Friendly names (`*.local.server`)

Traefik routes by name, but something must turn the name into
`192.168.1.50`. There is no local DNS, so add the names to `/etc/hosts` on
each computer that should use them (macOS: `sudo nano /etc/hosts`, then
`sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`):

```
192.168.1.50  home.local.server traefik.local.server photos.local.server jellyfin.local.server
192.168.1.50  request.local.server torrent.local.server indexers.local.server sonarr.local.server radarr.local.server subtitles.local.server
192.168.1.50  openwebui.local.server ollama.local.server search.local.server falaplay.local.server
```

TVs, phones and Android boxes can't do this, so they use the direct
`IP:port` addresses (Jellyfin 8096, Immich 2283).

HTTPS currently uses Traefik's built-in self-signed certificate, so browsers
show a warning once. To remove it, create a trusted certificate with
`mkcert` (`mkcert -install`, then
`mkcert -cert-file config/traefik/certs/local-server.crt -key-file config/traefik/certs/local-server.key local.server '*.local.server'`)
and add a Traefik file-provider config in `config/traefik/dynamic/` that
points to it. Not done yet.

## Disks and Folders

| Disk | Mounted at | Holds |
|---|---|---|
| Samsung SSD 850, 250 GB (LVM, root grown to 226 GB) | `/` | Ubuntu, Docker, this project, app settings, Immich database, thumbnails and ML models |
| APPLE HDD, 1 TB (ext4, label `data`) | `/srv/data` | Photos, movies, series, downloads |

The data disk is mounted by UUID in `/etc/fstab` with
`noatime,nofail,x-systemd.device-timeout=10s`: if it ever fails, the server
still boots and SSH keeps working. It spins down after 20 idle minutes
(`/etc/hdparm.conf`).

```text
<project>/config/<app>/             app settings (SSD)
<project>/data/immich/postgres/     Immich database (SSD)
<project>/data/immich/thumbs/       Immich thumbnails (SSD)
<project>/data/immich/model-cache/  Immich ML models (SSD)

/srv/data/photos/                   Immich UPLOAD_LOCATION (HDD)
  library/<user>/YYYY/MM/DD/        originals, sorted by the storage template
  upload/                           uploads not sorted yet
  encoded-video/                    transcoded videos (regenerable)
  profile/                          profile pictures
  backups/                          Immich's nightly database dumps
  thumbs/                           empty; thumbnails are mounted from the SSD
/srv/data/media/movies/             Jellyfin / Radarr
/srv/data/media/tv/                 Jellyfin / Sonarr
/srv/data/media/downloads/          qBittorrent (tv-sonarr/, radarr/ per category)
```

qBittorrent, Sonarr, Radarr and Bazarr all mount `/srv/data/media` as
`/data`, so they see the same paths (`/data/downloads`, `/data/tv`,
`/data/movies`). Because downloads and the library are on the same mount,
Sonarr/Radarr import finished files as **hardlinks**: instant, and no
second copy on the disk while the torrent keeps seeding.

Never add, move or delete files inside `/srv/data/photos` by hand: Immich
tracks every file in its database. The `.immich` files are Immich's mount
markers (it refuses to start if the disk is missing); leave them.

## Setup From Scratch

1. Mount the data disk at `/srv/data` and create
   `photos`, `media/movies`, `media/tv`, `media/downloads` (owned by your user).
2. `cp .env.example .env && chmod 600 .env`, then set at least:
   - `DB_PASSWORD`: `openssl rand -hex 24` (letters and numbers only)
   - `SEARXNG_SECRET`: `openssl rand -hex 32`
3. Create the app folders as your user, so Docker doesn't create them as root:
   `mkdir -p data/immich/{thumbs,model-cache} data/jellyfin-cache config/jellyfin config/traefik/{dynamic,certs}`
4. `docker compose up -d --wait`
5. Link the profile shortcuts:
   `for n in media-on media-off ai-on ai-off; do sudo ln -sfn "$PWD/scripts/profile-ctl.sh" /usr/local/bin/$n; done`
6. Install the weekly Immich update timer:
   `sudo cp system/immich-update.* /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now immich-update.timer`
7. Set up each app (sections below).

## Immich

- **Version:** `IMMICH_VERSION=release` (always the newest). The setup follows
  Immich's official v3 compose: upload mount at `/data`, Valkey as the job
  queue, health checks on.
- **Storage:** originals on the HDD (`UPLOAD_LOCATION=/srv/data/photos`),
  thumbnails on the SSD (mounted over `/data/thumbs`), so browsing is fast
  and the HDD can sleep.
- **Settings done in the web UI** (Administration > Settings):
  - Storage Template on: `{{y}}/{{MM}}/{{dd}}/{{filename}}`
  - Nightly tasks start at **02:00** (the server is unused 01:30–08:30)
- **Mobile app:** server `http://192.168.1.50:2283`.
- **Weekly update** (`immich-update.timer`, Sundays 04:30):
  `scripts/immich-update.sh` pulls the newest server, ML and Valkey images
  and restarts them. It first compares our database image with the one in
  Immich's official `docker-compose.yml`; if Immich now needs a different
  database, the update is skipped and logged. Then read the release notes
  and update `immich-postgres` in `docker-compose.yaml` by hand.
  Log: `journalctl -u immich-update`.
- **Requirements:** at least 6 GB RAM (8 GB here); the ML container needs an
  `x86-64-v2` CPU (Ivy Bridge qualifies).

## Jellyfin

- **Server** = the `jellyfin` container (always on). **App** = what you install
  on the TV/box; nothing else is needed on the server to watch.
- **Android TV box:** install "Jellyfin for Android TV" and use
  `http://192.168.1.50:8096`.
- **Libraries:** Filmes → `/media/movies`, Séries → `/media/tv`
  (`MEDIA_ROOT=/srv/data/media`). Metadata language Portuguese (Portugal).
- **Remote access:** "allow remote connections" stays on (needed for devices
  on the home network); automatic port mapping (UPnP) is off. Nothing is
  forwarded on the router, so it is not reachable from the internet.
- **Hardware transcoding:** `/dev/dri` is mapped into the container. The
  HD 4000 (Ivy Bridge, i965 driver) does **H.264 only**. In Dashboard >
  Playback > Transcoding: VAAPI, device `/dev/dri/renderD128`, hardware
  decoding for H264 only; leave HEVC encoding, tone mapping and low-power
  encoding off. HEVC/4K files must be played directly by the box (most can);
  if one stutters, it is being transcoded on the CPU.

### Jellyfin vs Seerr

- **Jellyfin** plays what is already on the server.
- **Seerr** is a request page for things you don't have yet. It doesn't
  play or download anything itself; it passes the request along. (Seerr
  replaced Jellyseerr and Overseerr in 2026, when the two projects merged.)

```
Seerr -> Radarr (movies) / Sonarr (series) -> Prowlarr finds it -> qBittorrent downloads it -> shows up in Jellyfin
```

That is why Jellyfin is always on, while Seerr sits in the `media`
profile with the downloaders: start the profile to request something, stop
it when the download is done.

### Media automation (how the apps are linked)

Containers reach each other by service name on the `proxy` network (e.g.
`http://sonarr:8989`), never through the `*.local.server` names.

1. **qBittorrent:** default save path `/data/downloads`, automatic torrent
   management on, categories `tv-sonarr` and `radarr`. WebUI user `admin`
   with your own password (Tools > Options > Web UI).
2. **Prowlarr:** apps Sonarr (`http://sonarr:8989`) and Radarr
   (`http://radarr:7878`) with full sync, so indexers added here appear in
   both. FlareSolverr is an indexer proxy (`http://flaresolverr:8191/`) used
   only by indexers with the tag `flaresolverr`. **No indexers are added**:
   that choice is yours.
3. **Sonarr / Radarr:** root folders `/data/tv` and `/data/movies`,
   hardlinks and renaming on, qBittorrent (`qbittorrent:8081`) as download
   client with categories `tv-sonarr` / `radarr`.
4. **Bazarr:** linked to `sonarr:8989` and `radarr:7878`; language profile
   "Português + English" (pt, en) applied to new series and movies; provider
   Podnapisi (no account). Add OpenSubtitles.com with your own account for
   better results.
5. **Seerr:** sign in with the Jellyfin account (Seerr has no password of
   its own; Jellyfin URL `http://jellyfin:8096`), libraries Filmes and
   Séries. Linked to Sonarr (`sonarr:8989`, `/data/tv`) and Radarr
   (`radarr:7878`, `/data/movies`), quality profile HD-1080p.

qBittorrent runs without a VPN.

## Local AI (`ai` profile)

Open WebUI offers two kinds of models, plus SearXNG for web search:

- **Local models** from Ollama (`docker compose exec -T ollama ollama pull llama3.2`).
  Free, private, but slow on this CPU and limited by 8 GB RAM.
- **Claude** through Anthropic's OpenAI-compatible endpoint
  (`https://api.anthropic.com/v1`), with `ANTHROPIC_API_KEY` in `.env`. The key
  comes from the Claude Console and is billed per use, separately from a
  Claude subscription. Use model ids such as `claude-opus-5-5`,
  `claude-sonnet-5-5` or `claude-haiku-5-5`. The compatibility layer is meant
  for testing: no prompt caching, no visible thinking, and Open WebUI must not
  send `temperature`/`top_p` (current Claude models reject non-default values).

Open WebUI stores these connection settings in its own database on first
start; later changes are made in its Admin Settings > Connections.

This is the heaviest group for 8 GB RAM: start it only when needed.

## Personal Projects: Self-hosted CI/CD

Personal web projects (private GitHub repos) are deployed here by a
**GitHub Actions self-hosted runner**. The runner opens an outbound
connection to GitHub and waits for jobs, so no router ports, public IP or
DNS are needed; if the server is off, jobs wait in GitHub's queue.

Pattern per project:

- Checks (format, types, tests) keep running on GitHub's hosted runners
  (`runs-on: ubuntu-latest`), so they don't load the server.
- A `deploy` job with `runs-on: self-hosted`, `needs: check`, only for
  pushes to `main`, runs `docker compose up -d --build` from the repo's own
  `docker-compose.yaml`, which joins the external `home-server_proxy`
  network for Traefik and publishes a port for tablets/phones.

Runner setup (one per repo; repo **Settings > Actions > Runners > New
self-hosted runner** gives a one-hour registration token):

```bash
# runs as the dedicated github-runner user (nologin, in the docker group)
sudo -u github-runner bash -c 'cd /opt/github-runner/<repo> && ./config.sh --unattended \
  --url https://github.com/hugomota/<repo> --token <token> --name home-server --labels home-server --work _work'
sudo bash -c 'cd /opt/github-runner/<repo> && ./svc.sh install github-runner && ./svc.sh start'
```

The `docker` group gives the runner root-level power over the host: use it
**only with private repositories** (a public repo would let anyone's pull
request run code here).

| Project | Address | Port |
|---|---|---|
| fala-play | `http://192.168.1.50:8090` / `https://falaplay.local.server` | 8090 |

## Photo Backup to AWS S3 (Deep Archive)

Glacier is now a **storage class inside S3**, not a separate service: you
create a normal private bucket and each file gets its class when uploaded.
`scripts/photos-glacier-backup.sh` uploads with
`--storage-class DEEP_ARCHIVE` (about $1/TB/month; restores take up to
12–48 h and cost money; each file is billed for at least 180 days).

How the script works: it compares Immich's originals (`library/` and
`upload/` under `PHOTOS_ROOT=/srv/data/photos`) with a manifest of what was
already sent (`backups/photos-glacier/manifest.txt`), zips only the new
files, uploads the zip, and only then records them. A failed run is safe to
retry.

### AWS setup (console)

1. **S3 > Create bucket** in `eu-west-1`: general purpose, block all public
   access ON, versioning off, SSE-S3 encryption, Object Lock off.
2. Bucket > **Management > Lifecycle rule**: delete incomplete multipart
   uploads after 7 days (failed uploads otherwise keep costing money).
3. **IAM > Users > Create user** `home-server-backup` (no console access) with
   an inline policy that can only add files to that bucket (no read, no
   delete, so a compromised server can't erase backups):

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

4. User > **Security credentials > Create access key** ("application running
   outside AWS"). Put the keys in `.env` yourself; never paste them in chat.
5. Optional: **Billing > Budgets**, monthly cost budget with an email alert.

### Plan and status

- **First backup (done by hand):** everything up to September 2026, uploaded in
  the console into `photos/` as `photos-backup-until-2026-09.zip` with storage
  class **Glacier Deep Archive** (set it under Properties before uploading).
- **From then on:** one zip per quarter with the photos that arrived in
  Immich since the last run (`photos-backup-2026-Q4.zip`, ...).
- **Before enabling the schedule:** mark everything already imported as backed
  up (fill the manifest), so the first automatic run doesn't upload it all
  again. Imported files get new file dates, so a date cutoff can't be used.
- **Not set up yet:** AWS CLI + `zip` on the host (`sudo apt install awscli zip`),
  the keys in `.env`, a test run, and a timer for 03:00 on
  1 Jan/Apr/Jul/Oct.

## Server Configuration Outside This Repo

These live on the host, not in Git; `/home/hmota/CLAUDE.md` has the details.

| What | Where |
|---|---|
| Data disk mount | `/etc/fstab` (backup `/etc/fstab.bak-2026-10-20`) |
| HDD spin-down (20 min) | `/etc/hdparm.conf` |
| Security updates (automatic) + reboot at 04:00 only when needed | `/etc/apt/apt.conf.d/52unattended-upgrades-local` |
| Unused hardware off (Wi-Fi, Bluetooth, sound) | `/etc/modprobe.d/blacklist-unused-hardware.conf` |
| Power saving at boot (PCI runtime PM except Ethernet, SATA link PM) | `/usr/local/sbin/powersave.sh` + `powersave.service` |
| Kernel power settings | `/etc/sysctl.d/60-powersave.conf` |
| Docker cleanup, Sundays 05:00 | `docker-cleanup.service` + `.timer` |
| Profile shortcuts | `/usr/local/bin/{media,ai}-{on,off}` → `scripts/profile-ctl.sh` |

The server is never used 01:30–08:30, so all scheduled work runs then:
Immich nightly tasks 02:00, photo backup 03:00 (quarterly), reboot if needed
04:00, Immich update 04:30 (Sundays), Docker cleanup 05:00 (Sundays). The
server stays on 24/7: sleeping a headless 2012 Mac risks losing SSH.

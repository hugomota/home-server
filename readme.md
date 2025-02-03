# Docker Media & Budget Stack

A self-hosted Docker stack combining media management and personal budgeting tools.

## Services Overview

| Service         | Port(s)               | Purpose                      | Web UI                          |
|-----------------|-----------------------|------------------------------|---------------------------------|
| **Actual Server** | 5006                 | Budgeting & finance tracking | `http://<IP>:5006`             |
| **Jellyfin**     | 8096 (HTTP)<br>8920 (HTTPS) | Media server & streaming    | `http://<IP>:8096`             |
| **Bazarr**       | 6767                 | Automatic subtitle downloads | `http://<IP>:6767`             |
| **Sonarr**       | 8989                 | TV show download automation  | `http://<IP>:8989`             |
| **Radarr**       | 7878                 | Movie download automation    | `http://<IP>:7878`             |

## Key Details

### 1. **Actual Server** (`actual_server`)
- **Purpose**: Personal budget management
- **Port**: 5006 TCP
- **Config Path**: `./config/actual`
- **Features**:
  - Expense tracking
  - Budget reports
  - Sync capabilities

### 2. **Jellyfin** (`jellyfin`)
- **Purpose**: Media streaming server
- **Ports**:
  - 8096: Web interface
  - 8920: HTTPS (optional)
- **Config Path**: `./config/jellyfin`
- **Media Path**: `./media`
- **Features**:
  - Hardware transcoding
  - Multi-user support
  - Client apps for all platforms

### 3. **Bazarr** (`bazarr`)
- **Purpose**: Subtitle management
- **Port**: 6767 TCP
- **Config Path**: `./config/bazarr`
- **Integrates With**: Jellyfin
- **Features**:
  - Supports 60+ subtitle providers
  - Automatic subtitle matching
  - Multi-language support

### 4. **Sonarr** (`sonarr`)
- **Purpose**: TV show management
- **Port**: 8989 TCP
- **Config Path**: `./config/sonarr`
- **Features**:
  - Automatic episode downloads
  - Quality management
  - Calendar view

### 5. **Radarr** (`radarr`)
- **Purpose**: Movie management
- **Port**: 7878 TCP
- **Config Path**: `./config/radarr`
- **Features**:
  - Movie database integration
  - 4K/HDR support
  - Automatic upgrade to better quality

---

## Network Diagram
```plaintext
+----------+       +--------+       +-----------------+
| Sonarr   | → → → | Media  | ← ← ← | Jellyfin        |
| (8989)   |       | Folder |       | (8096/8920)     |
+----------+       +--------+       +-----------------+
     ↑                ↑  ↑                ↑
     |                |  +----------------+
+----------+       +--------+       +-----------------+
| Radarr   | → → → |        | ← ← ← | Bazarr          |
| (7878)   |       |        |       | (6767)          |
+----------+       +--------+       +-----------------+

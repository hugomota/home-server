#!/usr/bin/env python3
"""Send one local pan/tilt command to the Xiaomi MJSXJ05CM."""

import argparse
import ipaddress
import json
import sys
from pathlib import Path

from miio.chuangmi_camera import ChuangmiCamera, Direction

CONFIG = Path("/Users/hugomota/Projects/home-server/config/go2rtc/xiaomi-ptz.json")
DIRECTIONS = {
    "left": Direction.Left,
    "right": Direction.Right,
    "up": Direction.Up,
    "down": Direction.Down,
}


def load_config() -> tuple[str, str]:
    data = json.loads(CONFIG.read_text())
    ip = str(data["ip"])
    token = str(data["token"])
    if not ipaddress.ip_address(ip).is_private:
        raise ValueError("Camera IP is not private")
    if len(token) != 32:
        raise ValueError("Invalid miIO token length")
    return ip, token


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("direction", choices=sorted(DIRECTIONS))
    parser.add_argument(
        "--dry-run", action="store_true", help="validate only; do not move"
    )
    args = parser.parse_args()

    try:
        ip, token = load_config()
    except Exception as exc:  # noqa: BLE001 - CLI boundary validates local config.
        print(f"PTZ configuration error: {exc}", file=sys.stderr)
        return 2

    if args.dry_run:
        print("PTZ configuration is valid; no movement command was sent.")
        return 0

    try:
        result = ChuangmiCamera(ip, token).rotate(DIRECTIONS[args.direction])
    except Exception as exc:  # noqa: BLE001 - CLI boundary reports device failures.
        print(f"PTZ command failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1

    print(f"PTZ {args.direction} command accepted: {result}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

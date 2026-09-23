#!/usr/bin/env python3
"""Interactively fetch and securely store the MJSXJ05CM miIO token."""

import json
import sys
from getpass import getpass
from pathlib import Path

from miio.cloud import CloudInterface

MODEL = "chuangmi.camera.ipc019"
DEST = Path("/Users/hugomota/Projects/home-server/config/go2rtc/xiaomi-ptz.json")


def main() -> int:
    print(
        "Xiaomi PTZ setup. Credentials are used only for this login and are not saved."
    )
    username = input("Xiaomi account email/phone: ").strip()
    password = getpass("Xiaomi account password: ")
    region = input("Mi Home region [de]: ").strip().lower() or "de"
    if not username or not password:
        print("Username and password are required.", file=sys.stderr)
        return 2

    try:
        devices = CloudInterface(username, password).get_devices(locale=region)
    except Exception as exc:  # noqa: BLE001 - CLI boundary reports provider failures.
        print(
            f"Xiaomi login/device lookup failed: {type(exc).__name__}: {exc}",
            file=sys.stderr,
        )
        return 1
    finally:
        password = ""

    matches = [device for device in devices.values() if device.model == MODEL]
    if not matches:
        print(f"No {MODEL} camera found in region {region}.", file=sys.stderr)
        return 1

    if len(matches) > 1:
        print("Matching cameras:")
        for index, device in enumerate(matches, 1):
            print(f"  {index}. {device.name}")
        try:
            selected = int(input("Choose camera number: ")) - 1
            device = matches[selected]
        except (ValueError, IndexError):
            print("Invalid selection.", file=sys.stderr)
            return 2
    else:
        device = matches[0]

    token = (device.token or "").strip()
    if len(token) != 32:
        print("Xiaomi did not return a valid 32-character miIO token.", file=sys.stderr)
        return 1

    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_text(
        json.dumps({"model": MODEL, "ip": device.ip, "token": token}) + "\n"
    )
    DEST.chmod(0o600)
    print(f"PTZ configuration saved securely for: {device.name}")
    print("The token was not printed and the Xiaomi password was not stored.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

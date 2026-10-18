#!/usr/bin/env bash
# Print one available iPhone simulator as: udid<TAB>name
# Prefers an exact "iPhone 16" on the newest iOS runtime.
set -euo pipefail

python3 - << 'PY'
import json
import subprocess
import sys

raw = subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "-j"],
    text=True,
)
devices = json.loads(raw).get("devices", {})

def runtime_version(key: str) -> tuple:
    marker = "iOS-"
    if marker not in key:
        return (0,)
    parts = []
    for piece in key.split(marker, 1)[1].split("-"):
        parts.append(int(piece) if piece.isdigit() else 0)
    return tuple(parts)

found = []
for runtime, entries in devices.items():
    if "iOS" not in runtime:
        continue
    version = runtime_version(runtime)
    for device in entries:
        if not device.get("isAvailable", False):
            continue
        name = device.get("name") or ""
        if "iPhone" not in name:
            continue
        found.append((version, name, device.get("udid", ""), runtime))

if not found:
    sys.stderr.write("No available iPhone simulator\n")
    subprocess.call(["xcrun", "simctl", "list", "devices", "available"])
    sys.exit(1)

def rank(item):
    version, name, _udid, _runtime = item
    if name == "iPhone 16":
        preference = 0
    elif name.startswith("iPhone 16"):
        preference = 1
    else:
        preference = 2
    return (preference, tuple(-part for part in version), name)

found.sort(key=rank)
version, name, udid, runtime = found[0]
if not udid:
    sys.stderr.write(f"Simulator {name} has no udid\n")
    sys.exit(1)
sys.stderr.write(f"Selected {name} ({udid}) on {runtime}\n")
print(f"{udid}\t{name}")
PY

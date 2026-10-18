#!/usr/bin/env bash
# Point xcode-select at the newest Xcode under /Applications.
set -euo pipefail

selected="$(python3 - << 'PY'
import plistlib
from pathlib import Path

apps = sorted(Path("/Applications").glob("Xcode*.app"))
if not apps:
    raise SystemExit("No Xcode.app under /Applications")

def version(app: Path) -> tuple:
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    raw = str(info.get("CFBundleShortVersionString") or "0")
    parts = []
    for piece in raw.split("."):
        parts.append(int(piece) if piece.isdigit() else 0)
    return tuple(parts)

print(max(apps, key=version))
PY
)"

echo "Using $selected"
sudo xcode-select -s "$selected"
xcodebuild -version
xcrun simctl list runtimes

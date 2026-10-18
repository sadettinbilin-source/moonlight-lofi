#!/usr/bin/env bash
# Copy screenshot attachments out of an xcresult into a flat folder.
# Tries the Xcode exporter first, then xcparse. A missing result bundle is
# not an error here, because the test step already failed. A bundle with no
# images is an error so a green run cannot hide a missed screenshot.
set -euo pipefail

XCRESULT="${1:-TestResults.xcresult}"
DEST="${2:-screenshots}"
mkdir -p "$DEST"

if [[ ! -d "$XCRESULT" ]]; then
  echo "No xcresult at $XCRESULT"
  exit 0
fi

RAW="$(mktemp -d)"
cleanup() { rm -rf "$RAW"; }
trap cleanup EXIT

try_export() {
  local tool="$1"
  shift
  echo "Trying: $*"
  if "$@" ; then
    return 0
  fi
  echo "$tool export failed"
  return 0
}

if xcrun xcresulttool help 2>&1 | grep -q "attachments"; then
  try_export xcresulttool xcrun xcresulttool export attachments --path "$XCRESULT" --output-path "$RAW/xcresulttool"
fi

count_images() {
  find "$RAW" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' \) | wc -l | tr -d ' '
}

if [[ "$(count_images)" -eq 0 ]]; then
  if ! command -v xcparse >/dev/null 2>&1; then
    brew install xcparse || brew install chargepoint/xcparse/xcparse || true
  fi
  if command -v xcparse >/dev/null 2>&1; then
    try_export xcparse xcparse screenshots "$XCRESULT" "$RAW/xcparse"
    if [[ "$(count_images)" -eq 0 ]]; then
      try_export xcparse xcparse attachments "$XCRESULT" "$RAW/xcparse-attachments"
    fi
  else
    echo "xcparse is not available"
  fi
fi

python3 - "$RAW" "$DEST" << 'PY'
import shutil
import sys
from pathlib import Path

raw = Path(sys.argv[1])
dest = Path(sys.argv[2])
dest.mkdir(parents=True, exist_ok=True)
images = [
    path for path in raw.rglob("*")
    if path.is_file() and path.suffix.lower() in {".png", ".jpg", ".jpeg", ".heic"}
]
used = set()
for path in sorted(images):
    parent = path.parent.name
    if path.stem.lower() in {"image", "screenshot", "attachment"} and parent not in {"", raw.name}:
        name = f"{parent}{path.suffix.lower()}"
    else:
        name = path.name
    candidate = name
    suffix = 2
    while candidate in used:
        candidate = f"{Path(name).stem}-{suffix}{Path(name).suffix}"
        suffix += 1
    used.add(candidate)
    shutil.copy2(path, dest / candidate)

print(f"Copied {len(images)} screenshot(s) to {dest}")
raise SystemExit(0 if images else 1)
PY

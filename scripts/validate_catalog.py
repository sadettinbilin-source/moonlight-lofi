#!/usr/bin/env python3
"""Check tracks.json against bundled audio before an Xcode build."""

import json
import re
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "MoonlightLofi" / "Resources" / "Catalog" / "tracks.json"
AUDIO = ROOT / "MoonlightLofi" / "Resources" / "Audio"
ID_RE = re.compile(r"^[a-z0-9-]+$")


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    tracks = catalog.get("tracks")
    if not isinstance(tracks, list) or not tracks:
        fail("tracks.json needs a non-empty tracks array")
    seen = set()
    free_ready = 0
    for track in tracks:
        track_id = track.get("id", "")
        if not ID_RE.match(track_id) or track_id in seen:
            fail(f"invalid or duplicate id: {track_id!r}")
        seen.add(track_id)
        if not str(track.get("title", "")).strip():
            fail(f"{track_id} is missing a title")
        duration = track.get("duration")
        if not isinstance(duration, (int, float)) or duration <= 0:
            fail(f"{track_id} needs a positive duration")
        bundled = track.get("bundledFile") or ""
        remote = track.get("fileURL") or ""
        if not bundled and not remote:
            fail(f"{track_id} needs bundledFile or fileURL")
        if remote and not str(remote).startswith("https://"):
            fail(f"{track_id} fileURL must be https")
        if bundled:
            path = AUDIO / bundled
            if not path.is_file():
                fail(f"missing audio file {path}")
            with wave.open(str(path), "rb") as handle:
                seconds = handle.getnframes() / float(handle.getframerate())
            if abs(seconds - float(duration)) > 0.5:
                fail(f"{track_id} duration is {duration} but {bundled} is {seconds:.2f}s")
        elif track.get("placeholder") and "example.com" not in str(remote):
            print(f"note: {track_id} is a placeholder but its URL is not example.com")
        if not track.get("isPro") and bundled and not track.get("placeholder"):
            free_ready += 1
    if free_ready < 2:
        fail("the free plan needs at least two playable bundled tracks")
    print(f"Catalog OK ({len(tracks)} tracks, {free_ready} free and playable)")


if __name__ == "__main__":
    main()

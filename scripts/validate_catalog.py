#!/usr/bin/env python3
"""Check tracks.json against bundled audio before an Xcode build."""

import json
import re
import struct
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "MoonlightLofi" / "Resources" / "Catalog" / "tracks.json"
AUDIO = ROOT / "MoonlightLofi" / "Resources" / "Audio"
ID_RE = re.compile(r"^[a-z0-9-]+$")
CONTAINER_TYPES = {b"moov", b"trak", b"mdia", b"minf", b"stbl"}


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def mp4_duration(path: Path) -> float:
    data = path.read_bytes()
    found = find_mvhd(data, 0, len(data))
    if found is None:
        fail(f"{path.name} has no mvhd duration")
    return found


def find_mvhd(data: bytes, start: int, end: int) -> float | None:
    index = start
    while index + 8 <= end:
        size = int.from_bytes(data[index : index + 4], "big")
        kind = data[index + 4 : index + 8]
        header = 8
        if size == 1 and index + 16 <= end:
            size = int.from_bytes(data[index + 8 : index + 16], "big")
            header = 16
        elif size == 0:
            size = end - index
        if size < header or index + size > end:
            return None
        body = index + header
        if kind == b"mvhd":
            return parse_mvhd(data[body : index + size])
        if kind in CONTAINER_TYPES:
            found = find_mvhd(data, body, index + size)
            if found is not None:
                return found
        index += size
    return None


def parse_mvhd(body: bytes) -> float:
    version = body[0]
    if version == 0:
        timescale = int.from_bytes(body[12:16], "big")
        duration = int.from_bytes(body[16:20], "big")
    else:
        timescale = int.from_bytes(body[20:24], "big")
        duration = int.from_bytes(body[24:32], "big")
    if timescale <= 0:
        fail("mvhd timescale is zero")
    return duration / timescale


def media_duration(path: Path) -> float:
    if path.suffix.lower() == ".wav":
        with wave.open(str(path), "rb") as handle:
            return handle.getnframes() / float(handle.getframerate())
    if path.suffix.lower() in {".m4a", ".mp4", ".aac"}:
        return mp4_duration(path)
    fail(f"unsupported audio file {path.name}")
    return 0


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
        if track.get("artist") != "Moonlight Lofi":
            fail(f"{track_id} artist must be Moonlight Lofi")
        if not str(track.get("key", "")).strip():
            fail(f"{track_id} is missing a key")
        bpm = track.get("bpm")
        if not isinstance(bpm, int) or isinstance(bpm, bool) or bpm <= 0:
            fail(f"{track_id} needs a positive bpm")
        if track.get("placeholder"):
            fail(f"{track_id} is still a placeholder")
        if track.get("seamless") is not True:
            fail(f"{track_id} must be a seamless loop")
        duration = track.get("duration")
        if not isinstance(duration, (int, float)) or isinstance(duration, bool) or duration <= 0:
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
            seconds = media_duration(path)
            if abs(seconds - float(duration)) > 0.5:
                fail(f"{track_id} duration is {duration} but {bundled} is {seconds:.2f}s")
        if not track.get("isPro") and bundled:
            free_ready += 1
    if free_ready < 2:
        fail("the free plan needs at least two playable bundled tracks")
    print(f"Catalog OK ({len(tracks)} tracks, {free_ready} free and playable)")


if __name__ == "__main__":
    main()

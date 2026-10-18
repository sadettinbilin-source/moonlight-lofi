#!/usr/bin/env python3
"""Generate short placeholder tones and the app icon.

These are not the channel's music. Replace the wav files in
MoonlightLofi/Resources/Audio with masters you own, and keep the
filenames in sync with tracks.json (or change the JSON).
"""

import math
import struct
import wave
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "MoonlightLofi" / "Resources" / "Audio"
ICON = ROOT / "MoonlightLofi" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
RATE = 22050
SECONDS = 10


class Noise:
    def __init__(self, seed: int) -> None:
        self.state = seed & 0x7FFFFFFF

    def next(self) -> float:
        self.state = (1103515245 * self.state + 12345) & 0x7FFFFFFF
        return (self.state / 0x7FFFFFFF) * 2 - 1


def tone(path: Path, frequencies: list[float], noise_amount: float, seed: int) -> None:
    count = RATE * SECONDS
    noise = Noise(seed)
    frames = bytearray()
    for index in range(count):
        t = index / RATE
        fade = min(1.0, t / 0.35) * min(1.0, (SECONDS - t) / 0.8)
        tremolo = 0.82 + 0.18 * math.sin(2 * math.pi * 0.35 * t)
        sample = 0.0
        for offset, frequency in enumerate(frequencies):
            weight = 0.22 if offset == 0 else 0.08
            sample += math.sin(2 * math.pi * frequency * t) * weight
        sample += noise.next() * noise_amount
        sample = max(-1.0, min(1.0, sample * fade * tremolo))
        frames += struct.pack("<h", int(sample * 32767))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(frames)


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_icon(path: Path) -> None:
    width = height = 1024
    raw = bytearray()
    stars = [(180, 220, 2), (300, 140, 2), (760, 180, 2), (840, 320, 1), (140, 420, 1), (620, 120, 1)]
    for y in range(height):
        raw.append(0)
        fade = y / height
        base_r = int(18 + 28 * (1 - fade))
        base_g = int(16 + 22 * (1 - fade))
        base_b = int(48 + 36 * (1 - fade))
        for x in range(width):
            red, green, blue = base_r, base_g, base_b
            dx = x - 512
            dy = y - 430
            distance = math.hypot(dx, dy)
            if distance < 210:
                shade = max(0.0, min(1.0, 1 - 0.12 * (dx / 210)))
                red, green, blue = int(236 * shade), int(228 * shade), int(255 * shade)
            elif distance < 310:
                glow = 1 - (distance - 210) / 100
                red = min(255, int(red + glow * 90))
                green = min(255, int(green + glow * 70))
                blue = min(255, int(blue + glow * 110))
            raw.extend((max(0, min(255, red)), max(0, min(255, green)), max(0, min(255, blue)), 255))
    for sx, sy, radius in stars:
        for y in range(sy - radius, sy + radius + 1):
            for x in range(sx - radius, sx + radius + 1):
                if 0 <= x < width and 0 <= y < height and (x - sx) ** 2 + (y - sy) ** 2 <= radius ** 2:
                    offset = y * (1 + width * 4) + 1 + x * 4
                    raw[offset:offset + 3] = b"\xff\xff\xff"
    png = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def main() -> None:
    tone(AUDIO / "midnight-kettle.wav", [196.0, 293.66], 0.0, 1)
    tone(AUDIO / "window-rain.wav", [146.83, 220.0], 0.015, 2)
    tone(AUDIO / "violet-hour.wav", [220.0, 329.63], 0.0, 3)
    write_icon(ICON)
    print(f"Wrote tones to {AUDIO}")
    print(f"Wrote {ICON}")


if __name__ == "__main__":
    main()

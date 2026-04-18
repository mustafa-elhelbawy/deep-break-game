#!/usr/bin/env python3
"""
generate_atlas.py
Creates the Deep Break placeholder sprite atlas (128x128 RGB PNG).
Run from project root: python3 tools/generate_atlas.py

No dependencies beyond Python 3 stdlib. Uses raw PNG chunk construction
so Pillow / ImageMagick are not required.

Phase 4 replaces this file with the real bioluminescent atlas.
The region_rect coordinates in all .tscn files are frozen to match this layout.
"""
import struct, zlib, os, math

# ── Atlas layout constants (must match .tscn region_rect values) ──────────────
WIDTH  = 128
HEIGHT = 128
BG     = (10, 14, 26)   # dark navy background

REGIONS = [
    # (x, y, w, h, fill_function_or_colour)
    # Phase 4: final bioluminescent palette — region coords are FROZEN, only colours updated.
    ("ball",    0,  0,  20, 20, "circle"),          # #e0ecff  WHITE_SOFT circle
    ("paddle",  0, 20, 120, 16, (0, 200, 184)),     # #00c8b8  TEAL
    ("tier0",   0, 36,  44, 18, (0, 200, 184)),     # #00c8b8  TEAL
    ("tier1",   0, 54,  44, 18, (0, 224, 255)),     # #00e0ff  CYAN
    ("tier2",   0, 72,  44, 18, (255, 193,   7)),   # #ffc107  AMBER
    ("tier3",   0, 90,  44, 18, (177, 103, 255)),   # #b167ff  VIOLET
]

def pixel_colour(px, py):
    for _, rx, ry, rw, rh, fill in REGIONS:
        if rx <= px < rx + rw and ry <= py < ry + rh:
            if fill == "circle":
                cx, cy, r = rx + rw / 2, ry + rh / 2, min(rw, rh) / 2 - 1
                if math.sqrt((px - cx)**2 + (py - cy)**2) <= r:
                    return (224, 236, 255)  # #e0ecff  WHITE_SOFT ball
                return BG
            return fill
    return BG

def write_png(path, w, h, pixel_fn):
    raw = b""
    for y in range(h):
        raw += b"\x00"  # PNG filter: None
        for x in range(w):
            r, g, b = pixel_fn(x, y)
            raw += bytes([r, g, b])

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    ihdr = chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    idat = chunk(b"IDAT", zlib.compress(raw, 9))
    iend = chunk(b"IEND", b"")

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + ihdr + idat + iend)
    print(f"✓  {path}  ({w}×{h} RGB PNG, {os.path.getsize(path)} bytes)")

if __name__ == "__main__":
    write_png("assets/textures/atlas.png", WIDTH, HEIGHT, pixel_colour)
    print()
    print("Atlas regions:")
    for name, x, y, w, h, _ in REGIONS:
        print(f"  {name:8s}  Rect2({x}, {y}, {w}, {h})")
    print()
    print("Next step: open Godot editor, click atlas.png in FileSystem,")
    print("go to Import tab, set Filter = Nearest, click Re-Import.")

#!/usr/bin/env python3
"""Art bible conformance checker.

Enforces the mechanical half of docs/ART_BIBLE.md so consistency is guaranteed by
CI rather than by memory:

  * every colour in every sprite appears in the locked palette
  * sprite dimensions match the spec for their directory
  * no stray colour-depth surprises

Zero dependencies -- decodes PNG with the stdlib so it runs anywhere, including a
git hook, without a virtualenv.

Usage:
    python3 tools/check_art.py [--palette assets/palette/emberwright.gpl]
Exit code 1 if any asset violates the bible.
"""

from __future__ import annotations

import argparse
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Directory -> (width, height). Width 0 means "any multiple of height" (sprite strips).
DIMENSION_RULES = {
    # Pokemon sprites are 96x96 (D-29 / D-30). The boss is nearest-neighbour x2
    # so it reads as bigger than everything it fights.
    "sprites/player":  (96, 96),
    "sprites/enemies": (96, 96),
    "sprites/elites":  (96, 96),
    "sprites/bosses":  (192, 192),
    "sprites/cards":   (80, 56),
    "sprites/frames":  (96, 132),
    "sprites/status":  (16, 16),
    "sprites/map":     (24, 24),
    # 30x30 as PokeAPI publishes them; padding to 32 would only add empty pixels.
    "sprites/relics":  (30, 30),
    "sprites/items":   (30, 30),
}

# Sprite strips are N frames wide; height must match exactly.
STRIP_DIRS = {"sprites/player", "sprites/enemies", "sprites/elites", "sprites/bosses"}


# --- minimal PNG decoding --------------------------------------------------

def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def read_png(path: Path):
    """Returns (width, height, set_of_rgba_tuples). Supports 8-bit PNGs."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")

    pos = 8
    width = height = depth = color_type = 0
    palette: list[tuple[int, int, int]] = []
    trns: list[int] = []
    idat = bytearray()

    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length  # length + type + data + crc

        if ctype == b"IHDR":
            width, height, depth, color_type = struct.unpack(">IIBB", chunk[:10])
        elif ctype == b"PLTE":
            palette = [tuple(chunk[i:i + 3]) for i in range(0, len(chunk), 3)]
        elif ctype == b"tRNS":
            trns = list(chunk)
        elif ctype == b"IDAT":
            idat += chunk
        elif ctype == b"IEND":
            break

    if depth != 8:
        raise ValueError(f"unsupported bit depth {depth} (export 8-bit PNG)")

    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color_type)
    if channels is None:
        raise ValueError(f"unsupported colour type {color_type}")

    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    out = bytearray(stride * height)
    prev = bytearray(stride)
    src = 0
    for y in range(height):
        filt = raw[src]
        src += 1
        line = bytearray(raw[src:src + stride])
        src += stride
        if filt == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif filt == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif filt == 3:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif filt == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                c = prev[i - channels] if i >= channels else 0
                line[i] = (line[i] + _paeth(a, prev[i], c)) & 0xFF
        elif filt != 0:
            raise ValueError(f"bad filter type {filt}")
        out[y * stride:(y + 1) * stride] = line
        prev = line

    colours = set()
    for i in range(0, len(out), channels):
        px = out[i:i + channels]
        if color_type == 6:
            r, g, b, a = px
        elif color_type == 2:
            (r, g, b), a = px, 255
        elif color_type == 3:
            idx = px[0]
            r, g, b = palette[idx] if idx < len(palette) else (0, 0, 0)
            a = trns[idx] if idx < len(trns) else 255
        elif color_type == 0:
            r = g = b = px[0]
            a = 255
        else:  # 4: grey + alpha
            r = g = b = px[0]
            a = px[1]
        if a != 0:  # fully transparent pixels carry no colour information
            colours.add((r, g, b))
    return width, height, colours


# --- palette ---------------------------------------------------------------

def read_gpl(path: Path) -> set[tuple[int, int, int]]:
    """Parses a GIMP .gpl palette (what Aseprite and Lospec both export)."""
    colours = set()
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) >= 3 and all(p.isdigit() for p in parts[:3]):
            colours.add(tuple(int(p) for p in parts[:3]))
    return colours


# --- checks ----------------------------------------------------------------

def rule_for(rel: Path):
    for prefix, dims in DIMENSION_RULES.items():
        if str(rel).startswith(prefix):
            return prefix, dims
    return None, None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--palette", default="assets/palette/emberwright.gpl")
    ap.add_argument("--assets", default="assets")
    args = ap.parse_args()

    pal_path = ROOT / args.palette
    if not pal_path.exists():
        print(f"note: no palette at {args.palette} yet -- checking dimensions only")
        palette = None
    else:
        palette = read_gpl(pal_path)
        print(f"palette: {len(palette)} colours from {args.palette}")
        if len(palette) > 32:
            print(f"  WARNING: art bible locks 32 colours, palette has {len(palette)}")

    pngs = sorted((ROOT / args.assets).rglob("*.png"))
    if not pngs:
        print("no PNGs found yet -- nothing to check")
        return 0

    errors = 0
    for png in pngs:
        rel = png.relative_to(ROOT / args.assets)
        try:
            w, h, colours = read_png(png)
        except Exception as exc:  # noqa: BLE001 - report and continue
            print(f"ERROR {rel}: {exc}")
            errors += 1
            continue

        prefix, dims = rule_for(rel)
        if dims:
            ew, eh = dims
            if prefix in STRIP_DIRS:
                if h != eh or w % ew != 0:
                    print(f"ERROR {rel}: {w}x{h}, expected {eh}px tall and a multiple of {ew} wide")
                    errors += 1
            elif (w, h) != (ew, eh):
                print(f"ERROR {rel}: {w}x{h}, expected {ew}x{eh}")
                errors += 1

        if palette:
            stray = colours - palette
            if stray:
                sample = ", ".join(f"#{r:02x}{g:02x}{b:02x}" for r, g, b in sorted(stray)[:6])
                more = f" (+{len(stray) - 6} more)" if len(stray) > 6 else ""
                print(f"ERROR {rel}: {len(stray)} colours outside the palette: {sample}{more}")
                errors += 1

    print(f"\nchecked {len(pngs)} sprites, {errors} violation(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

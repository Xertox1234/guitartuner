#!/usr/bin/env python3
"""Generate the LUMA app icon, drawn from the strobe language (EXPERIENCE §10).

The mark: a *glowing tuned ring* with a central lock column on the near-black
canvas — the in-tune moment, in the one sacred accent (mint #28F0C0). It reads at
a glance and matches the in-app accent.

Pure standard library — a tiny zlib PNG writer, no Pillow/numpy/network — so it
runs anywhere and the icon is reproducible (`python3 Tools/make_app_icon.py`).
Renders the iOS 1024 marketing icon (full-bleed, opaque) plus every macOS size
(on the rounded-rect "squircle" with a transparent margin, per the macOS grid),
straight into App/Assets.xcassets/AppIcon.appiconset/.
"""

import math
import os
import struct
import zlib

# ----- LUMA palette (sRGB 0..1), mirrors ds-tokens.css / StrobePalette(dark) -----
CANVAS = (0x0A / 255, 0x0B / 255, 0x10 / 255)   # #0A0B10 near-black, faint cool tint
LIFT   = (0x10 / 255, 0x13 / 255, 0x1E / 255)   # subtle central bg-grad lift
MINT   = (0x28 / 255, 0xF0 / 255, 0xC0 / 255)   # #28F0C0 sacred in-tune accent
WHITE  = (1.0, 1.0, 1.0)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "App", "Assets.xcassets", "AppIcon.appiconset"))

# macOS Big Sur icon grid: the rounded rect is ~80.5% of the canvas, corner
# radius ~0.181 of the canvas — leaving the standard transparent margin.
MAC_FRACTION = 0.805
MAC_RADIUS = 0.181


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def rrect_sdf(u, v, half, rad):
    """Signed distance to a rounded square centred at (0.5,0.5); <0 inside."""
    dx = abs(u - 0.5) - (half - rad)
    dy = abs(v - 0.5) - (half - rad)
    outside = math.hypot(max(dx, 0.0), max(dy, 0.0))
    inside = min(max(dx, dy), 0.0)
    return outside + inside - rad


def field(nx, ny, small):
    """Emissive scalar of the tuned-ring mark at content coord (nx,ny) in [-1,1]."""
    r = math.hypot(nx, ny)
    # A bolder, softer ring at tiny sizes so it never disappears.
    ring_r = 0.64
    ring_sigma = 0.075 if small else 0.052
    col_sigma = 0.085 if small else 0.058

    # The tuned ring — a glowing circle (the hero of the mark).
    ring = math.exp(-((r - ring_r) / ring_sigma) ** 2) * 1.22
    # The central lock column (the strobe frozen at in-tune), held *inside* the
    # ring so it reads as the lit column at lock, not a beam through it.
    col_x = math.exp(-(nx / col_sigma) ** 2)
    col_env = math.exp(-(ny / 0.42) ** 2)
    col = col_x * col_env * 1.16
    # Soft bloom so the whole mark emits rather than fills.
    bloom = math.exp(-(r / 0.52) ** 2) * 0.36
    return ring + col + bloom


def shade(nx, ny, r_norm, small):
    """Return sRGB (r,g,b) for a content pixel; r_norm is radius for the bg lift."""
    g = field(nx, ny, small)
    # Hotter core trends to white; faint glow stays mint.
    hot = smoothstep(0.70, 1.45, g)
    tint = tuple(MINT[i] + (WHITE[i] - MINT[i]) * hot for i in range(3))
    # Canvas with a gentle central lift gives the bloom somewhere to sit.
    base = tuple(CANVAS[i] + (LIFT[i] - CANVAS[i]) * math.exp(-(r_norm / 0.85) ** 2) for i in range(3))
    return tuple(min(1.0, base[i] + tint[i] * g) for i in range(3))


def render(size, mac):
    """Render one icon. iOS: full-bleed opaque RGB. macOS: squircle RGBA."""
    small = size <= 48
    has_alpha = mac
    bpp = 4 if has_alpha else 3
    buf = bytearray(size * size * bpp)
    aa = 1.6 / size  # ~1.6px edge antialias for the mac squircle

    if mac:
        half = MAC_FRACTION / 2.0
        content_half = half           # squircle bbox maps to content [-1,1]
    else:
        content_half = 0.5            # full canvas maps to content [-1,1]

    i = 0
    for py in range(size):
        v = (py + 0.5) / size
        for px in range(size):
            u = (px + 0.5) / size
            nx = (u - 0.5) / content_half
            ny = (v - 0.5) / content_half
            r_norm = math.hypot(nx, ny)
            rgb = shade(nx, ny, r_norm, small)
            if has_alpha:
                a = 1.0 - smoothstep(-aa, aa, rrect_sdf(u, v, half, MAC_RADIUS))
                buf[i] = int(rgb[0] * 255 + 0.5)
                buf[i + 1] = int(rgb[1] * 255 + 0.5)
                buf[i + 2] = int(rgb[2] * 255 + 0.5)
                buf[i + 3] = int(max(0.0, min(1.0, a)) * 255 + 0.5)
                i += 4
            else:
                buf[i] = int(rgb[0] * 255 + 0.5)
                buf[i + 1] = int(rgb[1] * 255 + 0.5)
                buf[i + 2] = int(rgb[2] * 255 + 0.5)
                i += 3
    return bytes(buf), bpp


def write_png(path, size, data, bpp):
    color_type = 6 if bpp == 4 else 2
    stride = size * bpp
    raw = bytearray()
    for y in range(size):
        raw.append(0)  # filter: none
        raw += data[y * stride:(y + 1) * stride]
    comp = zlib.compress(bytes(raw), 9)

    def chunk(typ, payload):
        return (struct.pack(">I", len(payload)) + typ + payload
                + struct.pack(">I", zlib.crc32(typ + payload) & 0xffffffff))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, color_type, 0, 0, 0))
           + chunk(b"IDAT", comp)
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


# (filename, pixel size, is_mac)
TARGETS = [
    ("icon-ios-1024.png", 1024, False),
    ("icon-mac-16.png", 16, True),
    ("icon-mac-16@2x.png", 32, True),
    ("icon-mac-32.png", 32, True),
    ("icon-mac-32@2x.png", 64, True),
    ("icon-mac-128.png", 128, True),
    ("icon-mac-128@2x.png", 256, True),
    ("icon-mac-256.png", 256, True),
    ("icon-mac-256@2x.png", 512, True),
    ("icon-mac-512.png", 512, True),
    ("icon-mac-512@2x.png", 1024, True),
]


def main():
    for name, size, mac in TARGETS:
        data, bpp = render(size, mac)
        write_png(os.path.join(OUT, name), size, data, bpp)
        print(f"  wrote {name} ({size}x{size}, {'RGBA' if bpp == 4 else 'RGB'})")
    print(f"Done -> {OUT}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate SilkBound's original pixel-art and procedural audio assets.

Only Python's standard library is required. Re-run from the repository root:
    python3 tools/generate_assets.py
"""
from __future__ import annotations

import math
import random
import struct
import wave
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def canvas(width: int, height: int, color=(0, 0, 0, 0)):
    return [list([tuple(color)] * width) for _ in range(height)]


def put(img, x, y, color):
    if 0 <= y < len(img) and 0 <= x < len(img[0]):
        img[y][x] = tuple(color)


def rect(img, x, y, w, h, color):
    for py in range(max(0, y), min(len(img), y + h)):
        for px in range(max(0, x), min(len(img[0]), x + w)):
            img[py][px] = tuple(color)


def line(img, x0, y0, x1, y1, color):
    dx, sx = abs(x1 - x0), 1 if x0 < x1 else -1
    dy, sy = -abs(y1 - y0), 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        put(img, x0, y0, color)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def ellipse(img, cx, cy, rx, ry, color, fill=True):
    for y in range(max(0, cy - ry), min(len(img), cy + ry + 1)):
        for x in range(max(0, cx - rx), min(len(img[0]), cx + rx + 1)):
            q = ((x - cx) / max(1, rx)) ** 2 + ((y - cy) / max(1, ry)) ** 2
            if q <= 1.0 and (fill or q > 0.72):
                put(img, x, y, color)


def save_png(path: Path, img):
    height, width = len(img), len(img[0])
    raw = bytearray()
    for row in img:
        raw.append(0)
        for pixel in row:
            raw.extend(bytes(pixel))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    data = b"\x89PNG\r\n\x1a\n"
    data += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    data += chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


TILE_COLORS = {
    1: ((85, 65, 74, 255), (120, 83, 77, 255), (46, 46, 62, 255)),
    2: ((106, 83, 70, 255), (143, 111, 86, 255), (61, 57, 65, 255)),
    3: ((48, 55, 69, 255), (78, 85, 101, 255), (29, 38, 57, 255)),
    4: ((61, 70, 83, 255), (229, 171, 83, 255), (28, 37, 51, 255)),
    5: ((65, 67, 79, 255), (75, 207, 205, 255), (32, 43, 57, 255)),
    6: ((57, 68, 82, 255), (164, 182, 190, 255), (26, 39, 54, 255)),
    7: ((30, 34, 49, 255), (124, 71, 94, 255), (13, 19, 34, 255)),
    8: ((47, 49, 83, 255), (112, 185, 207, 255), (27, 31, 57, 255)),
    9: ((22, 74, 103, 210), (62, 176, 188, 210), (15, 43, 73, 220)),
    10: ((79, 87, 83, 255), (138, 157, 143, 255), (48, 59, 63, 255)),
    11: ((33, 61, 79, 255), (76, 205, 214, 255), (19, 34, 54, 255)),
    12: ((47, 82, 66, 255), (116, 201, 135, 255), (27, 48, 44, 255)),
    13: ((103, 74, 62, 255), (184, 123, 77, 255), (53, 46, 52, 255)),
    14: ((38, 56, 76, 255), (76, 133, 153, 255), (20, 33, 52, 255)),
    15: ((54, 70, 88, 255), (117, 158, 177, 255), (25, 40, 58, 255)),
    16: ((42, 60, 76, 255), (214, 156, 79, 255), (21, 36, 54, 255)),
    17: ((42, 67, 84, 255), (111, 230, 229, 255), (21, 39, 57, 255)),
    18: ((86, 72, 65, 255), (199, 150, 92, 255), (47, 44, 50, 255)),
    19: ((42, 58, 76, 255), (85, 204, 199, 255), (18, 33, 52, 255)),
    20: ((50, 64, 80, 255), (192, 113, 81, 255), (21, 33, 48, 255)),
    21: ((58, 30, 48, 255), (231, 69, 91, 255), (22, 28, 47, 255)),
}


def make_tile_atlas():
    tile_size, columns, rows = 16, 8, 3
    img = canvas(tile_size * columns, tile_size * rows)
    for tile_id in range(1, 22):
        ox, oy = (tile_id % columns) * tile_size, (tile_id // columns) * tile_size
        base, highlight, shadow = TILE_COLORS[tile_id]
        for y in range(tile_size):
            for x in range(tile_size):
                edge = y == 0 or x == 0
                put(img, ox + x, oy + y, highlight if edge and tile_id not in (9,) else base)
        rng = random.Random(tile_id * 817)
        for _ in range(13):
            x, y = rng.randrange(2, 15), rng.randrange(2, 15)
            put(img, ox + x, oy + y, highlight if rng.random() > 0.42 else shadow)
        if tile_id in (4, 5, 8, 11, 17, 21):
            line(img, ox + 4, oy + 12, ox + 8, oy + 5, highlight)
            line(img, ox + 8, oy + 5, ox + 12, oy + 10, highlight)
        elif tile_id == 9:
            line(img, ox + 1, oy + 5, ox + 8, oy + 4, highlight)
            line(img, ox + 8, oy + 4, ox + 15, oy + 6, highlight)
            line(img, ox + 2, oy + 11, ox + 12, oy + 10, shadow)
        elif tile_id == 12:
            line(img, ox + 8, oy + 15, ox + 8, oy + 3, highlight)
            line(img, ox + 8, oy + 9, ox + 4, oy + 6, highlight)
            line(img, ox + 8, oy + 11, ox + 12, oy + 7, highlight)
        elif tile_id in (14, 15, 20):
            rect(img, ox + 2, oy + 2, 12, 2, highlight)
            line(img, ox + 3, oy + 6, ox + 3, oy + 14, shadow)
        elif tile_id == 16:
            rect(img, ox + 4, oy + 2, 8, 13, base)
            rect(img, ox + 6, oy + 4, 1, 10, highlight)
            put(img, ox + 10, oy + 9, highlight)
        elif tile_id == 17:
            rect(img, ox + 6, oy + 2, 4, 5, highlight)
            rect(img, ox + 7, oy + 8, 2, 6, shadow)
            line(img, ox + 3, oy + 5, ox + 1, oy + 3, highlight)
            line(img, ox + 12, oy + 5, ox + 14, oy + 3, highlight)
        elif tile_id == 18:
            rect(img, ox + 2, oy + 3, 12, 10, base)
            rect(img, ox + 7, oy + 3, 2, 10, highlight)
            rect(img, ox + 2, oy + 7, 12, 2, shadow)
        elif tile_id == 19:
            rect(img, ox + 2, oy + 9, 12, 3, highlight)
            rect(img, ox + 4, oy + 12, 2, 3, shadow)
            rect(img, ox + 10, oy + 12, 2, 3, shadow)
        elif tile_id == 21:
            line(img, ox + 7, oy, ox + 9, oy + 5, highlight)
            line(img, ox + 9, oy + 5, ox + 5, oy + 9, highlight)
            line(img, ox + 5, oy + 9, ox + 10, oy + 15, highlight)
    save_png(ROOT / "assets/tiles/terrain_atlas.png", img)


def make_rover():
    frame_w, frame_h, frames = 32, 48, 8
    img = canvas(frame_w * frames, frame_h)
    outline, suit, mid, trim = (12, 22, 38, 255), (47, 77, 105, 255), (76, 133, 157, 255), (232, 180, 99, 255)
    visor, glint = (24, 52, 69, 255), (97, 224, 222, 255)
    for frame in range(frames):
        ox = frame * frame_w
        leg_l, leg_r = (3, 0) if frame in (1, 4) else ((0, 3) if frame == 2 else (1, 1))
        # Heavy boots and separated legs keep the silhouette readable at phone scale.
        rect(img, ox + 10 + leg_l, 36, 5, 8, outline)
        rect(img, ox + 17 + leg_r, 36, 5, 8, outline)
        rect(img, ox + 9 + leg_l, 42, 7, 3, trim)
        rect(img, ox + 16 + leg_r, 42, 7, 3, trim)
        rect(img, ox + 9, 22, 14, 16, outline)
        rect(img, ox + 10, 23, 12, 13, suit)
        rect(img, ox + 12, 25, 8, 8, mid)
        rect(img, ox + 13, 28, 6, 2, trim)
        rect(img, ox + 7, 24, 3, 10, outline)
        rect(img, ox + 8, 25, 2, 8, mid)
        rect(img, ox + 22, 24, 3, 10, outline)
        rect(img, ox + 23, 25, 2, 8, mid)
        # Helmet ring, faceplate and twin blue information lights.
        rect(img, ox + 9, 6, 14, 16, outline)
        rect(img, ox + 10, 5, 12, 15, trim)
        rect(img, ox + 11, 7, 10, 11, suit)
        rect(img, ox + 12, 9, 8, 7, visor)
        rect(img, ox + 13, 10, 4, 2, glint)
        put(img, ox + 19, 8, (255, 225, 163, 255))
        rect(img, ox + 8, 14, 2, 4, outline)
        rect(img, ox + 22, 14, 2, 4, outline)
        # The mining, attack and hurt frames communicate action even without text.
        if frame == 4:
            line(img, ox + 23, 27, ox + 29, 21, trim)
            line(img, ox + 29, 21, ox + 31, 13, glint)
            put(img, ox + 31, 12, (236, 251, 244, 255))
        elif frame == 5:
            line(img, ox + 24, 28, ox + 30, 31, trim)
            line(img, ox + 30, 31, ox + 31, 38, glint)
        elif frame == 6:
            rect(img, ox + 8, 7, 2, 12, (220, 94, 102, 255))
            rect(img, ox + 22, 7, 2, 12, (220, 94, 102, 255))
        elif frame == 7:
            rect(img, ox + 9, 35, 14, 5, outline)
            rect(img, ox + 6, 39, 20, 4, suit)
    save_png(ROOT / "assets/characters/rover_sheet.png", img)


def make_creatures():
    # Four frame, 32-pixel-wide crystalline scavenger.
    bug = canvas(128, 32)
    for f in range(4):
        ox = f * 32
        body = (67, 114, 119, 255)
        ellipse(bug, ox + 16, 18, 10, 7, (16, 31, 49, 255))
        ellipse(bug, ox + 16, 16, 9, 6, body)
        ellipse(bug, ox + 22, 15, 4, 4, (137, 220, 191, 255))
        put(bug, ox + 23, 14, (248, 224, 149, 255))
        bounce = 1 if f in (1, 3) else 0
        for lx, by in ((9, 21), (14, 22), (20, 22), (24, 21)):
            line(bug, ox + lx, by, ox + lx - 3, 27 + bounce, (34, 53, 67, 255))
        line(bug, ox + 11, 12, ox + 7, 7, (105, 184, 185, 255))
        line(bug, ox + 21, 12, ox + 25, 7, (105, 184, 185, 255))
        if f == 2:
            line(bug, ox + 6, 11, ox + 3, 14, (232, 182, 107, 255))
    save_png(ROOT / "assets/characters/crystal_scavenger_sheet.png", bug)

    drone = canvas(96, 32)
    for f in range(3):
        ox = f * 32
        rect(drone, ox + 8, 8, 16, 15, (14, 24, 42, 255))
        rect(drone, ox + 10, 7, 12, 14, (62, 84, 106, 255))
        rect(drone, ox + 13, 11, 7, 4, (90, 220, 223, 255))
        put(drone, ox + 16, 13, (249, 101, 95, 255))
        rect(drone, ox + 3, 11, 5, 3, (175, 90, 93, 255))
        rect(drone, ox + 24, 11, 5, 3, (175, 90, 93, 255))
        line(drone, ox + 9, 23, ox + 6, 27, (221, 168, 91, 255))
        line(drone, ox + 23, 23, ox + 26, 27, (221, 168, 91, 255))
        if f == 1:
            rect(drone, ox + 2, 8, 28, 2, (232, 73, 94, 255))
    save_png(ROOT / "assets/characters/admin_drone_sheet.png", drone)

    iri = canvas(32, 48)
    vale = canvas(32, 48)
    for img, coat, accent, hair in ((iri, (108, 129, 96, 255), (224, 173, 97, 255), (91, 64, 58, 255)), (vale, (77, 99, 133, 255), (99, 218, 210, 255), (49, 47, 64, 255))):
        rect(img, 10, 20, 12, 17, (18, 31, 46, 255))
        rect(img, 11, 21, 10, 15, coat)
        rect(img, 12, 6, 9, 14, (20, 35, 48, 255))
        rect(img, 13, 7, 7, 11, hair)
        rect(img, 14, 10, 6, 5, (184, 138, 111, 255))
        rect(img, 14, 12, 4, 2, accent)
        rect(img, 9, 24, 3, 9, accent)
        rect(img, 20, 24, 3, 9, accent)
        rect(img, 10, 35, 5, 9, (27, 39, 55, 255))
        rect(img, 17, 35, 5, 9, (27, 39, 55, 255))
        rect(img, 8, 42, 7, 3, (14, 24, 37, 255))
        rect(img, 17, 42, 7, 3, (14, 24, 37, 255))
    save_png(ROOT / "assets/characters/iri.png", iri)
    save_png(ROOT / "assets/characters/vale.png", vale)


def make_ship():
    img = canvas(256, 128)
    # Salvage vessel: asymmetrical repair plates, blue nav glass, no canon vessel references.
    ellipse(img, 123, 74, 103, 32, (15, 25, 41, 255))
    rect(img, 28, 59, 176, 31, (31, 47, 67, 255))
    rect(img, 48, 48, 106, 15, (44, 65, 83, 255))
    rect(img, 154, 52, 48, 20, (57, 78, 94, 255))
    line(img, 44, 62, 16, 45, (159, 183, 187, 255))
    line(img, 16, 45, 10, 62, (159, 183, 187, 255))
    line(img, 77, 50, 98, 28, (106, 138, 152, 255))
    line(img, 98, 28, 137, 28, (106, 138, 152, 255))
    line(img, 137, 28, 151, 51, (106, 138, 152, 255))
    rect(img, 104, 34, 38, 14, (20, 49, 67, 255))
    rect(img, 109, 37, 29, 8, (77, 202, 212, 255))
    rect(img, 65, 70, 18, 10, (212, 154, 84, 255))
    rect(img, 92, 69, 16, 12, (151, 88, 76, 255))
    rect(img, 124, 68, 17, 13, (82, 120, 134, 255))
    rect(img, 164, 73, 22, 8, (106, 188, 183, 255))
    rect(img, 34, 88, 31, 9, (35, 46, 63, 255))
    rect(img, 164, 90, 31, 8, (35, 46, 63, 255))
    line(img, 32, 91, 22, 111, (83, 112, 132, 255))
    line(img, 190, 92, 208, 111, (83, 112, 132, 255))
    for x in (45, 69, 93, 117, 141, 165, 189):
        put(img, x, 61, (237, 185, 104, 255))
    # Repair seams and a subtle, non-magical information-light lattice.
    line(img, 52, 54, 67, 61, (111, 199, 196, 255))
    line(img, 67, 61, 58, 69, (111, 199, 196, 255))
    save_png(ROOT / "assets/ship/salvage_vessel.png", img)


def make_backgrounds():
    specs = {
        "ashlands": ((10, 18, 37, 255), (24, 34, 56, 255), (99, 54, 58, 255), (187, 93, 64, 255)),
        "glassfall": ((9, 14, 31, 255), (23, 30, 56, 255), (92, 40, 75, 255), (199, 57, 73, 255)),
        "drowned": ((8, 26, 45, 255), (20, 55, 72, 255), (42, 104, 117, 255), (110, 160, 150, 255)),
    }
    for name, (top, mid, ridge, glow) in specs.items():
        width, height = 512, 288
        img = canvas(width, height)
        for y in range(height):
            t = y / height
            blend = tuple(int(top[i] * (1 - t) + mid[i] * t) for i in range(4))
            for x in range(width):
                put(img, x, y, blend)
        rng = random.Random(name)
        # Dust motes, distant stars, and faint telemetry-like points.
        for _ in range(130):
            x, y = rng.randrange(width), rng.randrange(190)
            c = (81, 151, 176, 170) if rng.random() < 0.12 else (164, 187, 198, 110)
            put(img, x, y, c)
        ellipse(img, 386, 98, 65, 65, (39, 48, 77, 255))
        ellipse(img, 386, 98, 61, 61, glow)
        ellipse(img, 386, 98, 53, 53, (53, 47, 73, 255))
        ellipse(img, 369, 98, 61, 61, top)  # a dark eclipse, not a gateway
        for x in range(width):
            horizon = 213 + int(11 * math.sin(x / 31.0) + 8 * math.sin(x / 13.0))
            rect(img, x, horizon, 1, height - horizon, ridge)
            if x % 47 == 0:
                rect(img, x, horizon - rng.randrange(9, 28), rng.randrange(3, 8), rng.randrange(14, 30), (31, 43, 60, 255))
        for _ in range(180):
            x, y = rng.randrange(width), rng.randrange(220, height)
            if img[y][x][3] != 0:
                put(img, x, y, glow if rng.random() < 0.15 else (52, 52, 68, 255))
        save_png(ROOT / f"assets/environments/{name}_parallax.png", img)


def make_item_icons():
    img = canvas(128, 64)
    palette = [
        (174, 183, 187, 255), (207, 153, 92, 255), (79, 207, 204, 255),
        (173, 105, 112, 255), (143, 112, 192, 255), (117, 197, 137, 255),
        (218, 182, 113, 255), (93, 202, 218, 255), (226, 225, 204, 255),
        (230, 113, 123, 255), (108, 142, 181, 255), (211, 174, 124, 255),
        (84, 208, 191, 255), (197, 147, 88, 255), (160, 176, 184, 255),
        (100, 227, 217, 255), (206, 163, 102, 255), (81, 134, 177, 255),
        (211, 184, 112, 255), (110, 205, 200, 255), (206, 90, 105, 255),
        (145, 189, 198, 255), (90, 174, 143, 255), (206, 111, 174, 255),
    ]
    for i in range(24):
        ox, oy = (i % 8) * 16, (i // 8) * 16
        col = palette[i]
        rect(img, ox + 3, oy + 4, 10, 9, (18, 29, 45, 255))
        rect(img, ox + 4, oy + 3, 8, 10, col)
        rect(img, ox + 6, oy + 5, 3, 2, (235, 233, 207, 255))
        if i % 4 == 0:
            line(img, ox + 4, oy + 12, ox + 12, oy + 4, (246, 226, 169, 255))
        elif i % 4 == 1:
            rect(img, ox + 7, oy + 3, 2, 10, (37, 46, 61, 255))
        elif i % 4 == 2:
            ellipse(img, ox + 8, oy + 8, 4, 4, col, fill=False)
        else:
            put(img, ox + 12, oy + 4, (255, 226, 161, 255))
    save_png(ROOT / "assets/ui/item_icons.png", img)


def make_icon():
    size = 512
    img = canvas(size, size, (8, 15, 31, 255))
    # Layered outer ring, a red eclipsed disk, and a repeatable blue-white weave.
    ellipse(img, 256, 256, 209, 209, (25, 43, 66, 255))
    ellipse(img, 256, 256, 193, 193, (72, 118, 139, 255), fill=False)
    ellipse(img, 256, 256, 157, 157, (12, 24, 43, 255))
    ellipse(img, 288, 250, 112, 112, (180, 56, 72, 255))
    ellipse(img, 239, 239, 117, 117, (8, 15, 31, 255))
    for k in range(16):
        angle = math.tau * k / 16
        x0, y0 = int(256 + math.cos(angle) * 122), int(256 + math.sin(angle) * 122)
        x1, y1 = int(256 + math.cos(angle + math.pi / 3) * 122), int(256 + math.sin(angle + math.pi / 3) * 122)
        line(img, x0, y0, x1, y1, (63, 202, 213, 255))
    ellipse(img, 256, 256, 22, 22, (227, 187, 111, 255))
    ellipse(img, 256, 256, 9, 9, (235, 239, 223, 255))
    # Heavy inset corners give a crisp launcher silhouette at small sizes.
    for x in (53, 443):
        for y in (53, 443):
            rect(img, x, y, 16, 16, (118, 205, 205, 255))
    save_png(ROOT / "assets/ui/silkbound_icon.png", img)


def write_wav(path: Path, frequency: float, duration: float, kind: str, seed: int):
    rate = 22050
    count = int(rate * duration)
    rng = random.Random(seed)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        samples = bytearray()
        phase = 0.0
        for i in range(count):
            t = i / rate
            if kind == "ambience":
                swell = 0.5 + 0.5 * math.sin(math.tau * t / duration)
                sample = 0.11 * math.sin(math.tau * frequency * t) + 0.045 * math.sin(math.tau * (frequency * 1.47) * t)
                sample += (rng.random() * 2 - 1) * 0.035 * swell
            elif kind == "impact":
                env = math.exp(-t * 19.0)
                sample = env * (0.52 * math.sin(math.tau * (frequency - 140 * t) * t) + 0.18 * (rng.random() * 2 - 1))
            elif kind == "alert":
                env = min(1.0, t * 28.0) * math.exp(-t * 3.2)
                sample = env * 0.42 * math.sin(math.tau * (frequency + 210 * math.sin(math.tau * 5 * t)) * t)
            else:
                env = min(1.0, t * 50.0) * math.exp(-t * 9.0)
                sample = env * (0.35 * math.sin(math.tau * frequency * t) + 0.12 * math.sin(math.tau * (frequency * 1.8) * t))
            value = max(-1.0, min(1.0, sample))
            samples.extend(struct.pack("<h", int(value * 32767)))
        out.writeframes(samples)


def make_audio():
    specs = {
        "ambience_ashlands.wav": (61, 5.0, "ambience"),
        "ambience_glassfall.wav": (47, 5.0, "ambience"),
        "ambience_drowned.wav": (72, 5.0, "ambience"),
        "mine_impact.wav": (165, 0.22, "impact"),
        "pickup_chime.wav": (740, 0.18, "tone"),
        "jump_thrust.wav": (210, 0.16, "tone"),
        "craft_chime.wav": (525, 0.28, "tone"),
        "warning_pulse.wav": (340, 0.60, "alert"),
        "tool_swing.wav": (280, 0.14, "impact"),
    }
    for i, (name, (freq, duration, kind)) in enumerate(specs.items()):
        write_wav(ROOT / "assets/audio" / name, freq, duration, kind, i * 31 + 7)


def main():
    make_tile_atlas()
    make_rover()
    make_creatures()
    make_ship()
    make_backgrounds()
    make_item_icons()
    make_icon()
    make_audio()
    print("Generated SilkBound pixel art and procedural audio in assets/.")


if __name__ == "__main__":
    main()

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


def polygon(img, points, color):
    """Fill a low-resolution polygon without antialiasing or external image libraries."""
    if len(points) < 3:
        return
    min_y = max(0, min(point[1] for point in points))
    max_y = min(len(img) - 1, max(point[1] for point in points))
    for y in range(min_y, max_y + 1):
        scan_y = y + 0.5
        intersections = []
        for index, (x0, y0) in enumerate(points):
            x1, y1 = points[(index + 1) % len(points)]
            if (y0 <= scan_y < y1) or (y1 <= scan_y < y0):
                intersections.append(x0 + (scan_y - y0) * (x1 - x0) / (y1 - y0))
        intersections.sort()
        for index in range(0, len(intersections) - 1, 2):
            left = max(0, math.ceil(intersections[index]))
            right = min(len(img[0]), math.ceil(intersections[index + 1]))
            for x in range(left, right):
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
    5: ((72, 62, 70, 255), (235, 132, 78, 255), (33, 36, 52, 255)),
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
    """Four deterministically varied, ID-stable 16px material tiles.

    Tile ID 0 remains transparent. Variant groups use index
    tile_id + 22 * variant, keeping the first group's existing atlas offsets
    unchanged for crafting previews and preserving serialized tile IDs.
    """
    tile_size, columns, variants, stride = 16, 8, 4, 22
    rows = math.ceil((stride * variants) / columns)
    img = canvas(columns * tile_size, rows * tile_size)
    for variant in range(variants):
        for tile_id in range(1, 22):
            index = tile_id + stride * variant
            ox, oy = (index % columns) * tile_size, (index // columns) * tile_size
            base, highlight, shadow = TILE_COLORS[tile_id]
            rng = random.Random(tile_id * 1009 + variant * 7919)
            # Natural materials avoid complete per-cell bevel borders.
            if tile_id not in (12, 17, 19):
                rect(img, ox, oy, 16, 16, base)

            if tile_id in (1, 2, 3, 10):
                # Localized strata, broken facets, cinders and mineral grains.
                if tile_id == 3:
                    for _ in range(3):
                        x, y = rng.randrange(2, 12), rng.randrange(3, 13)
                        polygon(img, [(ox + x, oy + y), (ox + x + 4, oy + y - 2),
                                      (ox + x + 5, oy + y + 3)], shadow)
                    line(img, ox + 2 + variant, oy + 11, ox + 6 + variant, oy + 7, highlight)
                    line(img, ox + 6 + variant, oy + 7, ox + 11, oy + 10, shadow)
                else:
                    for _ in range(4):
                        x, y = rng.randrange(0, 14), rng.randrange(2, 15)
                        line(img, ox + x, oy + y, ox + min(15, x + rng.randrange(2, 5)),
                             oy + y, shadow if rng.random() < 0.55 else highlight)
                    for _ in range(5):
                        put(img, ox + rng.randrange(16), oy + rng.randrange(16), shadow)
                if tile_id == 1:
                    rect(img, ox + 3 + variant, oy + 4, 3, 1, (178, 91, 70, 255))
                elif tile_id == 2:
                    line(img, ox + 1, oy + 12, ox + 7, oy + 13, (175, 133, 97, 255))
                elif tile_id == 10:
                    line(img, ox + 3, oy + 10, ox + 11, oy + 10, (116, 145, 130, 255))
            elif tile_id in (4, 5):
                # Veins are colored differently enough to read at phone scale:
                # ferrite is golden iron; copper is orange conductive metal.
                vein = (232, 168, 80, 255) if tile_id == 4 else (236, 126, 72, 255)
                edge = (118, 84, 70, 255) if tile_id == 4 else (98, 63, 68, 255)
                x = 3 + variant
                polygon(img, [(ox + x, oy + 15), (ox + x + 2, oy + 10),
                              (ox + x + 5, oy + 9), (ox + x + 7, oy + 3),
                              (ox + x + 9, oy + 5), (ox + x + 7, oy + 11),
                              (ox + x + 4, oy + 12), (ox + x + 3, oy + 15)], edge)
                line(img, ox + x + 1, oy + 14, ox + x + 5, oy + 9, vein)
                line(img, ox + x + 5, oy + 9, ox + x + 7, oy + 4, vein)
                rect(img, ox + 10, oy + 2 + (variant % 3), 2, 2, highlight)
                for _ in range(3):
                    put(img, ox + rng.randrange(16), oy + rng.randrange(16), shadow)
            elif tile_id == 6:
                # Wreck plate, oblique brace and two distinct fasteners.
                polygon(img, [(ox + 1, oy + 4), (ox + 13, oy + 1),
                              (ox + 15, oy + 11), (ox + 3, oy + 14)], shadow)
                line(img, ox + 3, oy + 5 + variant % 3, ox + 13, oy + 3, highlight)
                line(img, ox + 4, oy + 12, ox + 13, oy + 8, (102, 130, 143, 255))
                put(img, ox + 5, oy + 8, (208, 163, 95, 255))
                put(img, ox + 12, oy + 5, (208, 163, 95, 255))
            elif tile_id == 7:
                # Faceted near-black volcanic glass with thin exposed fracture.
                polygon(img, [(ox + 0, oy + 5), (ox + 9, oy + 0),
                              (ox + 14, oy + 9), (ox + 7, oy + 15)],
                        (39, 35, 60, 255))
                polygon(img, [(ox + 7, oy + 3), (ox + 15, oy + 1),
                              (ox + 13, oy + 12)], shadow)
                line(img, ox + 6 + variant % 3, oy + 3,
                     ox + 10 + variant % 3, oy + 10, (174, 89, 120, 255))
                line(img, ox + 10 + variant % 3, oy + 10,
                     ox + 8, oy + 14, (105, 55, 99, 255))
            elif tile_id == 8:
                # Refractive silicate prism, cyan body and navy facets.
                polygon(img, [(ox + 3, oy + 6), (ox + 9, oy + 0),
                              (ox + 15, oy + 9), (ox + 8, oy + 15)],
                        (48, 109, 137, 255))
                polygon(img, [(ox + 9, oy + 0), (ox + 15, oy + 9),
                              (ox + 8, oy + 15)], (31, 63, 105, 255))
                line(img, ox + 3, oy + 6, ox + 9, oy + 1, (145, 220, 233, 255))
                line(img, ox + 9, oy + 1, ox + 12, oy + 8, (189, 237, 240, 255))
            elif tile_id == 9:
                # Partly translucent water, quiet short ripples and deep bands.
                rect(img, ox, oy, 16, 16, (25, 73, 103, 200))
                for y in (4, 10, 14):
                    x = (variant * 3 + y) % 6
                    line(img, ox + x, oy + y, ox + x + 7, oy + y,
                         (103, 207, 211, 215) if y == 4 else (55, 150, 173, 190))
                rect(img, ox + 2, oy + 7, 4, 1, (23, 62, 92, 220))
            elif tile_id == 11:
                # Cold Administration archive PCB; no sentient presence.
                rect(img, ox + 2, oy + 1, 12, 14, (25, 46, 68, 255))
                rect(img, ox + 4, oy + 3, 9, 3, (63, 151, 165, 255))
                for dx in range(4):
                    rect(img, ox + 4 + dx * 2, oy + 8, 1, 5 - dx % 2, highlight)
                line(img, ox + 1, oy + 14, ox + 13, oy + 14, shadow)
                put(img, ox + 12, oy + 12, (237, 178, 100, 255))
            elif tile_id == 12:
                # Sprouting resin growth; background remains transparent.
                x = 7 + variant % 3
                line(img, ox + x, oy + 15, ox + x, oy + 4, (63, 137, 90, 255))
                line(img, ox + x, oy + 10, ox + x - 5, oy + 5, highlight)
                line(img, ox + x, oy + 8, ox + x + 5, oy + 3, highlight)
                polygon(img, [(ox + x - 6, oy + 5), (ox + x - 3, oy + 4),
                              (ox + x - 3, oy + 9)], (128, 211, 128, 255))
                polygon(img, [(ox + x + 3, oy + 3), (ox + x + 6, oy + 2),
                              (ox + x + 4, oy + 7)], (96, 192, 135, 255))
                rect(img, ox + x - 1, oy + 13, 3, 3, shadow)
            elif tile_id == 13:
                # Staggered salvaged bricks, deliberately modular.
                rect(img, ox, oy, 16, 16, (71, 53, 54, 255))
                rect(img, ox, oy + 1, 8 + (variant % 4), 6, (141, 89, 69, 255))
                rect(img, ox + 9, oy + 1, 7, 6, (123, 78, 64, 255))
                rect(img, ox + 1, oy + 9, 11, 6, (161, 105, 72, 255))
                rect(img, ox + 13, oy + 9, 3, 6, (117, 78, 71, 255))
                line(img, ox + 1, oy + 11, ox + 10, oy + 11, (179, 123, 91, 255))
            elif tile_id in (14, 15, 20):
                # Structural metal components: readable construction modules.
                rect(img, ox + 1, oy + 1, 14, 14, shadow)
                rect(img, ox + 2, oy + 2, 12, 11, base)
                for x in (3, 12):
                    put(img, ox + x, oy + 3, highlight)
                    put(img, ox + x, oy + 12, highlight)
                if tile_id == 14:
                    line(img, ox + 4, oy + 7, ox + 11, oy + 7, highlight)
                    rect(img, ox + 7, oy + 5, 2, 5, (28, 50, 68, 255))
                elif tile_id == 15:
                    rect(img, ox + 2, oy + 6, 12, 3, highlight)
                    rect(img, ox + 4, oy + 9, 8, 2, (20, 47, 66, 255))
                else:
                    line(img, ox + 2, oy + 13, ox + 13, oy + 2, (203, 123, 93, 255))
                    line(img, ox + 3, oy + 12, ox + 13, oy + 12, highlight)
            elif tile_id == 16:
                # Pressure door with vertical seam, handle, and control strip.
                rect(img, ox + 3, oy, 10, 16, shadow)
                rect(img, ox + 4, oy + 1, 8, 14, base)
                rect(img, ox + 6, oy + 2, 1, 12, (139, 159, 169, 255))
                rect(img, ox + 10, oy + 6, 2, 3, highlight)
                line(img, ox + 4, oy + 14, ox + 11, oy + 14, (146, 168, 181, 255))
            elif tile_id == 17:
                # Survey lamp: compact exposed light above a slender mounting stem.
                rect(img, ox + 6, oy + 8, 4, 7, shadow)
                rect(img, ox + 7, oy + 8, 2, 6, highlight)
                rect(img, ox + 3, oy + 3, 10, 6, (24, 56, 71, 255))
                rect(img, ox + 5, oy + 2, 6, 5, (119, 236, 224, 255))
                rect(img, ox + 6, oy + 2, 3, 2, (238, 251, 224, 255))
            elif tile_id == 18:
                rect(img, ox + 1, oy + 3, 14, 11, shadow)
                rect(img, ox + 2, oy + 4, 12, 8, (141, 103, 72, 255))
                line(img, ox + 3, oy + 4, ox + 12, oy + 12, highlight)
                line(img, ox + 12, oy + 4, ox + 3, oy + 12, shadow)
                rect(img, ox + 7, oy + 4, 3, 3, (227, 187, 111, 255))
            elif tile_id == 19:
                rect(img, ox + 1, oy + 6, 14, 4, highlight)
                rect(img, ox + 2, oy + 5, 12, 3, (25, 52, 71, 255))
                for x in (3, 12):
                    rect(img, ox + x, oy + 10, 2, 6, shadow)
                rect(img, ox + 6, oy + 3, 5, 3, (214, 163, 100, 255))
                put(img, ox + 8, oy + 4, (126, 225, 216, 255))
            elif tile_id == 21:
                # Red shear glass; fractured material, not Starsilk or a portal.
                polygon(img, [(ox + 0, oy + 5), (ox + 10, oy + 0),
                              (ox + 15, oy + 10), (ox + 4, oy + 15)],
                        (71, 32, 51, 255))
                x = 6 + variant % 3
                line(img, ox + x, oy, ox + x + 3, oy + 5, (252, 104, 119, 255))
                line(img, ox + x + 3, oy + 5, ox + x - 2, oy + 11,
                     (224, 66, 99, 255))
                line(img, ox + x - 2, oy + 11, ox + x + 1, oy + 15,
                     (252, 104, 119, 255))
                rect(img, ox + 1, oy + 12, 3, 1, (117, 49, 71, 255))
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
    width, height = 512, 288
    for name, (top, mid, ridge, glow) in specs.items():
        img = canvas(width, height)
        for y in range(height):
            t = y / height
            blend = tuple(int(top[i] * (1 - t) + mid[i] * t) for i in range(4))
            for x in range(width):
                put(img, x, y, blend)
        rng = random.Random(name)
        # Keep the same cold starfield and eclipsed body as a system-wide visual anchor.
        for _ in range(130):
            x, y = rng.randrange(width), rng.randrange(190)
            color = (81, 151, 176, 170) if rng.random() < 0.12 else (164, 187, 198, 110)
            put(img, x, y, color)
        ellipse(img, 386, 98, 65, 65, (39, 48, 77, 255))
        ellipse(img, 386, 98, 61, 61, glow)
        ellipse(img, 386, 98, 53, 53, (53, 47, 73, 255))
        ellipse(img, 369, 98, 61, 61, top)  # a dark eclipse, not a gateway

        if name == "ashlands":
            horizons = []
            for x in range(width):
                horizon = 213 + int(11 * math.sin(x / 31.0) + 8 * math.sin(x / 13.0))
                horizons.append(horizon)
                rect(img, x, horizon, 1, height - horizon, ridge)
            # A collapsed, nonfunctional salvage gantry is a distant scale reference.
            iron = (25, 34, 47, 255)
            seam = (123, 71, 66, 255)
            base = horizons[129]
            line(img, 91, horizons[91], 104, 165, iron)
            line(img, 104, 165, 158, 179, iron)
            line(img, 158, 179, 171, horizons[171], iron)
            line(img, 104, 165, 129, base, iron)
            line(img, 158, 179, 137, base, iron)
            line(img, 104, 165, 171, horizons[171], iron)
            line(img, 104, 173, 158, 187, seam)
            line(img, 116, 168, 115, 184, iron)
            line(img, 148, 177, 145, 193, iron)
            # Silt has covered the feet; only a few seams still catch the eclipse.
            for x in (107, 121, 145, 160):
                rect(img, x, horizons[x] - 2, 7, 2, (143, 83, 65, 255))
            for x in range(12, width, 31):
                y = horizons[x] + 12 + rng.randrange(2, 11)
                line(img, x, y, x + rng.randrange(4, 10), y - 1, (132, 72, 65, 255))

        elif name == "glassfall":
            horizons = []
            for x in range(width):
                horizon = 219 + int(4 * math.sin(x / 29.0) + 3 * math.sin(x / 11.0))
                horizons.append(horizon)
                rect(img, x, horizon, 1, height - horizon, ridge)
            deep_glass = (48, 33, 63, 255)
            mid_glass = (79, 39, 75, 255)
            # The far crust is a broken mineral skyline, not the rolling ash hills.
            polygon(
                img,
                [(0, 224), (0, 216), (33, 209), (59, 217), (82, 158), (103, 218),
                 (145, 220), (176, 187), (205, 221), (245, 216), (278, 128),
                 (319, 220), (354, 212), (389, 173), (412, 218), (452, 204),
                 (478, 215), (512, 205), (512, 288), (0, 288)],
                deep_glass,
            )
            polygon(img, [(81, 217), (82, 158), (103, 218)], mid_glass)
            polygon(img, [(278, 217), (278, 128), (319, 220)], mid_glass)
            polygon(img, [(388, 217), (389, 173), (412, 218)], mid_glass)
            # Thin fractured edges only; no luminous portal or magical geometry.
            line(img, 82, 158, 101, 207, (151, 62, 92, 255))
            line(img, 278, 128, 314, 203, (177, 63, 91, 255))
            line(img, 389, 173, 409, 208, (141, 58, 91, 255))
            line(img, 173, 242, 207, 231, (142, 58, 85, 255))
            line(img, 207, 231, 223, 240, (142, 58, 85, 255))
            line(img, 223, 240, 256, 228, (142, 58, 85, 255))
            for x in (80, 177, 278, 389, 476):
                y = horizons[x] + 8
                line(img, x, y, x + 6, y - 2, glow if x == 278 else (129, 59, 88, 255))

        else:
            # Water flattens the horizon; the structures are mostly below its line.
            waterline = 222
            rect(img, 0, waterline, width, height - waterline, ridge)
            polygon(
                img,
                [(0, 224), (0, 213), (36, 210), (74, 217), (112, 211), (150, 216),
                 (184, 211), (226, 218), (260, 209), (299, 215), (337, 210),
                 (374, 216), (413, 208), (450, 216), (480, 211), (512, 215),
                 (512, 288), (0, 288)],
                (18, 49, 67, 255),
            )
            pole = (38, 65, 74, 255)
            hull = (31, 58, 69, 255)
            dim_light = (101, 159, 157, 220)
            # Survey pylons and a broken hull interrupt the empty flood horizon.
            line(img, 90, 256, 95, 164, pole)
            line(img, 94, 256, 99, 166, pole)
            line(img, 95, 164, 110, 177, pole)
            line(img, 87, 187, 105, 188, pole)
            line(img, 91, 205, 109, 213, pole)
            rect(img, 92, 170, 8, 4, dim_light)
            rect(img, 87, 190, 3, 3, (179, 112, 84, 230))
            line(img, 264, 257, 264, 181, pole)
            line(img, 268, 257, 268, 184, pole)
            line(img, 266, 190, 239, 198, pole)
            line(img, 266, 196, 290, 207, pole)
            line(img, 239, 198, 233, 219, pole)
            line(img, 290, 207, 296, 222, pole)
            rect(img, 262, 185, 9, 3, dim_light)
            polygon(img, [(151, 239), (166, 231), (181, 229), (200, 232), (215, 230),
                          (244, 239), (237, 244), (220, 248), (176, 247), (163, 245)], hull)
            line(img, 166, 231, 183, 225, pole)
            line(img, 183, 225, 205, 226, pole)
            line(img, 205, 226, 215, 230, pole)
            line(img, 197, 232, 204, 219, pole)
            rect(img, 179, 236, 4, 2, dim_light)
            rect(img, 210, 236, 4, 2, dim_light)
            # Broken reflections are horizontal and intermittent, never a complete mirror.
            for y, x0, length in ((228, 351, 38), (235, 388, 27), (244, 366, 46),
                                  (255, 403, 23), (268, 379, 35)):
                rect(img, x0, y, length, 1, (79, 139, 142, 128))
            for _ in range(54):
                x = rng.randrange(width)
                y = rng.randrange(waterline + 5, height - 2)
                if rng.random() < 0.68:
                    line(img, x, y, min(width - 1, x + rng.randrange(3, 12)), y,
                         (78, 133, 139, 100))

        for _ in range(95):
            x, y = rng.randrange(width), rng.randrange(220, height)
            if rng.random() < 0.15:
                put(img, x, y, glow)
            elif name != "drowned":
                put(img, x, y, (52, 52, 68, 255))
        save_png(ROOT / f"assets/environments/{name}_parallax.png", img)


def make_item_icons():
    """Purpose-drawn pixel pictograms, matching ItemCatalog icon indices.

    The existing 8-column, 16-pixel slot layout is unchanged, while the fourth
    atlas row now distinguishes specialized upgrades from ordinary materials.
    """
    img = canvas(128, 64)
    ink = (14, 24, 39, 255)
    rim = (47, 67, 82, 255)
    silver = (174, 194, 203, 255)
    light = (238, 237, 216, 255)
    cyan = (94, 220, 221, 255)
    deep_blue = (43, 99, 132, 255)
    copper = (229, 134, 83, 255)
    amber = (226, 178, 100, 255)
    burgundy = (168, 72, 91, 255)
    green = (112, 201, 139, 255)

    for index in range(27):
        tile = canvas(16, 16)
        if index == 0:  # Hull scrap: jagged clipped sheet with rivets.
            polygon(tile, [(2, 4), (10, 2), (14, 7), (12, 13), (4, 14), (1, 10)], ink)
            polygon(tile, [(3, 5), (10, 3), (12, 7), (10, 12), (4, 12)], silver)
            line(tile, 4, 10, 11, 6, rim)
            put(tile, 5, 6, amber)
            put(tile, 10, 10, amber)
        elif index == 1:  # Ferrite: chipped iron ore.
            polygon(tile, [(2, 10), (5, 3), (11, 2), (15, 10), (9, 14), (3, 13)], ink)
            polygon(tile, [(4, 10), (6, 4), (10, 4), (13, 10), (9, 12)], silver)
            line(tile, 6, 11, 10, 6, amber)
            put(tile, 11, 5, light)
        elif index == 2:  # Copper: distinguishable warm coil.
            rect(tile, 3, 4, 10, 9, ink)
            for x in (4, 7, 10):
                rect(tile, x, 5, 2, 7, copper)
            line(tile, 2, 3, 13, 3, amber)
            put(tile, 13, 13, light)
        elif index == 3:  # Volcanic glass: fractured rose-black shard.
            polygon(tile, [(8, 1), (14, 10), (8, 15), (2, 12)], ink)
            polygon(tile, [(8, 2), (12, 10), (8, 13), (4, 11)], (108, 60, 102, 255))
            line(tile, 8, 3, 9, 11, (243, 123, 158, 255))
            line(tile, 9, 11, 6, 13, burgundy)
        elif index == 4:  # Silicate crystal: bright bifaceted prism.
            polygon(tile, [(8, 1), (14, 7), (9, 15), (3, 9)], ink)
            polygon(tile, [(8, 2), (12, 7), (8, 13), (4, 8)], deep_blue)
            polygon(tile, [(8, 2), (12, 7), (8, 13)], cyan)
            line(tile, 6, 5, 8, 3, light)
        elif index == 5:  # Resin fiber: paired green strands.
            for dx in (4, 9):
                line(tile, dx, 14, dx + 2, 3, ink)
                line(tile, dx + 1, 13, dx + 3, 3, green)
            line(tile, 6, 9, 3, 6, green)
            line(tile, 11, 9, 14, 6, (167, 224, 137, 255))
            rect(tile, 4, 13, 9, 2, rim)
        elif index == 6:  # Organic gel: chemistry vial.
            rect(tile, 5, 1, 6, 3, silver)
            rect(tile, 4, 4, 8, 11, ink)
            rect(tile, 5, 7, 6, 6, green)
            rect(tile, 6, 5, 2, 2, light)
            put(tile, 9, 10, cyan)
            put(tile, 7, 12, light)
        elif index == 7:  # Archive shard: broken data tile.
            polygon(tile, [(2, 2), (11, 2), (14, 5), (14, 12), (9, 14), (2, 12)], ink)
            rect(tile, 4, 4, 8, 8, deep_blue)
            for x in (5, 7, 10):
                rect(tile, x, 6, 1, 5, cyan)
            put(tile, 11, 4, amber)
            put(tile, 12, 11, light)
        elif index == 8:  # Packed silt: granular sandpile.
            polygon(tile, [(1, 13), (5, 7), (8, 4), (12, 9), (15, 13)], ink)
            polygon(tile, [(3, 12), (7, 6), (9, 7), (13, 12)], (174, 145, 108, 255))
            put(tile, 7, 8, light)
            put(tile, 11, 11, rim)
        elif index == 9:  # Field ration: sealed survival packet.
            rect(tile, 3, 2, 10, 13, ink)
            rect(tile, 4, 3, 8, 10, burgundy)
            rect(tile, 4, 5, 8, 3, amber)
            line(tile, 6, 11, 10, 11, light)
            put(tile, 11, 4, light)
        elif index == 10:  # Medfoam: medical capsule with cross.
            rect(tile, 4, 2, 8, 13, ink)
            rect(tile, 5, 3, 6, 11, silver)
            rect(tile, 7, 5, 2, 7, burgundy)
            rect(tile, 5, 7, 6, 2, burgundy)
            rect(tile, 5, 12, 6, 2, deep_blue)
        elif index == 11:  # Salvaged brick: split stone block.
            rect(tile, 1, 4, 14, 9, ink)
            rect(tile, 2, 5, 12, 7, (167, 111, 79, 255))
            line(tile, 2, 8, 13, 8, (82, 62, 65, 255))
            line(tile, 7, 5, 7, 8, (82, 62, 65, 255))
            line(tile, 10, 9, 10, 12, (82, 62, 65, 255))
            put(tile, 4, 6, amber)
        elif index == 12:  # Shelter wall: pressure-sealed panel.
            rect(tile, 2, 2, 12, 12, ink)
            rect(tile, 3, 3, 10, 10, deep_blue)
            rect(tile, 5, 4, 6, 2, cyan)
            for x in (4, 11):
                put(tile, x, 11, silver)
        elif index == 13:  # Decking: wide horizontal grating.
            rect(tile, 1, 5, 14, 7, ink)
            rect(tile, 2, 6, 12, 3, silver)
            for x in (4, 8, 12):
                rect(tile, x, 6, 1, 6, rim)
            line(tile, 2, 10, 13, 10, amber)
        elif index == 14:  # Pressure door: tall sealed entry.
            rect(tile, 4, 1, 8, 14, ink)
            rect(tile, 5, 2, 6, 12, (91, 131, 158, 255))
            rect(tile, 6, 3, 1, 10, light)
            put(tile, 10, 9, amber)
            rect(tile, 5, 13, 6, 1, rim)
        elif index == 15:  # Survey lamp: bright lamp on mount.
            rect(tile, 7, 8, 2, 6, silver)
            rect(tile, 5, 13, 6, 2, ink)
            ellipse(tile, 8, 6, 5, 5, deep_blue)
            ellipse(tile, 8, 5, 3, 3, cyan)
            rect(tile, 7, 3, 2, 2, light)
        elif index == 16:  # Field storage crate.
            rect(tile, 2, 4, 12, 10, ink)
            rect(tile, 3, 5, 10, 8, (149, 105, 72, 255))
            line(tile, 4, 6, 11, 12, amber)
            line(tile, 11, 6, 4, 12, (88, 59, 56, 255))
            rect(tile, 6, 4, 4, 2, silver)
        elif index == 17:  # Workbench: engineering tabletop.
            rect(tile, 1, 5, 14, 4, ink)
            rect(tile, 2, 5, 12, 2, silver)
            rect(tile, 3, 9, 2, 6, rim)
            rect(tile, 11, 9, 2, 6, rim)
            rect(tile, 7, 3, 4, 2, amber)
            put(tile, 9, 4, cyan)
        elif index == 18:  # Reinforced panel: structural shield.
            polygon(tile, [(2, 2), (13, 2), (15, 6), (12, 14), (4, 14), (1, 7)], ink)
            polygon(tile, [(4, 4), (12, 4), (13, 7), (11, 12), (5, 12), (3, 7)], silver)
            line(tile, 4, 11, 12, 5, rim)
            line(tile, 5, 5, 11, 12, copper)
        elif index == 19:  # Repair kit: emergency toolbox.
            rect(tile, 2, 5, 12, 9, ink)
            rect(tile, 3, 6, 10, 6, (183, 98, 76, 255))
            rect(tile, 6, 3, 5, 3, silver)
            rect(tile, 7, 7, 2, 5, light)
            rect(tile, 5, 9, 6, 2, light)
            rect(tile, 10, 6, 2, 2, amber)
        elif index == 20:  # Field coil: conductive winding.
            rect(tile, 4, 2, 8, 12, ink)
            for y in (4, 7, 10):
                line(tile, 5, y, 11, y + 1, copper)
            rect(tile, 2, 6, 3, 4, silver)
            rect(tile, 11, 6, 3, 4, silver)
            put(tile, 8, 2, light)
        elif index == 21:  # Coolant loop: closed thermal exchanger.
            ellipse(tile, 8, 8, 7, 6, ink)
            ellipse(tile, 8, 8, 5, 4, cyan, fill=False)
            rect(tile, 6, 1, 4, 3, silver)
            rect(tile, 6, 12, 4, 3, deep_blue)
            put(tile, 3, 8, light)
        elif index == 22:  # Salvage cutter: diamond-tipped cutting tool.
            line(tile, 3, 13, 10, 4, ink)
            line(tile, 5, 13, 12, 4, silver)
            polygon(tile, [(10, 2), (14, 3), (13, 7), (9, 6)], cyan)
            rect(tile, 2, 12, 5, 3, amber)
            put(tile, 13, 2, light)
        elif index == 23:  # Survey scanner: blue lens handset.
            rect(tile, 3, 2, 10, 13, ink)
            rect(tile, 4, 3, 8, 10, rim)
            ellipse(tile, 8, 7, 4, 4, cyan)
            ellipse(tile, 8, 7, 2, 2, deep_blue)
            rect(tile, 6, 12, 4, 2, amber)
            put(tile, 8, 6, light)
        elif index == 24:  # Thermal lining: crossed insulation strips.
            rect(tile, 3, 2, 10, 12, ink)
            rect(tile, 4, 3, 8, 10, (179, 111, 86, 255))
            for y in (4, 7, 10):
                line(tile, 4, y, 11, y + 2, amber)
            line(tile, 4, 12, 11, 4, light)
        elif index == 25:  # Cargo frame: open structural rack.
            rect(tile, 2, 2, 12, 12, ink)
            rect(tile, 4, 4, 8, 8, (0, 0, 0, 0))
            for x in (2, 13):
                rect(tile, x, 2, 2, 12, silver)
            line(tile, 4, 4, 11, 11, copper)
            line(tile, 11, 4, 4, 11, amber)
        elif index == 26:  # Scanner lens: independent optical module.
            ellipse(tile, 8, 8, 7, 7, ink)
            ellipse(tile, 8, 8, 5, 5, silver)
            ellipse(tile, 8, 8, 4, 4, deep_blue)
            ellipse(tile, 8, 8, 2, 2, cyan)
            put(tile, 6, 6, light)
        ox, oy = (index % 8) * 16, (index // 8) * 16
        for y, row in enumerate(tile):
            for x, color in enumerate(row):
                if color[3] != 0:
                    put(img, ox + x, oy + y, color)
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

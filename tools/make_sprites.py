#!/usr/bin/env python3
"""Draws the cat sprite sheet (sprites/cat.png). Stdlib only.

Sheet: 32x32 frames, one row per animation, in the order of ROWS below.
Brain.js ANIMS must match the row order and frame counts.
Recolor by editing PALETTE and re-running.
"""
import os, struct, zlib

S = 32
PALETTE = {
    "O": (43, 34, 51),     # outline
    "F": (242, 166, 90),   # fur
    "S": (217, 136, 69),   # fur shade (far legs, tail tip)
    "B": (255, 241, 220),  # belly / muzzle
    "E": (43, 34, 51),     # eye
    "N": (242, 140, 160),  # nose
    "H": (229, 72, 77),    # heart
    "Z": (255, 255, 255),  # zzz
}


def grid():
    return [[None] * S for _ in range(S)]


def px(g, x, y, c):
    if 0 <= x < S and 0 <= y < S:
        g[y][x] = c


def rect(g, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(g, x, y, c)


def ellipse(g, cx, cy, rx, ry, c):
    for y in range(S):
        for x in range(S):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                g[y][x] = c


def outline(g):
    edge = [(x, y) for y in range(S) for x in range(S) if g[y][x] is None and any(
        0 <= x + dx < S and 0 <= y + dy < S and g[y + dy][x + dx] is not None
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in edge:
        g[y][x] = "O"


def head(g, cx, cy, eye="open"):
    ellipse(g, cx, cy, 5, 4.5, "F")
    for ex, tip in ((cx - 3, cx - 3), (cx + 2, cx + 3)):  # ears
        rect(g, ex, cy - 5, ex + 1, cy - 5, "F")
        px(g, tip, cy - 6, "F")
    rect(g, cx + 3, cy + 2, cx + 4, cy + 2, "B")
    px(g, cx + 5, cy + 1, "N")
    ex = cx + 2
    if eye == "open":
        rect(g, ex, cy - 1, ex, cy, "E")
    elif eye == "closed":
        rect(g, ex - 1, cy, ex, cy, "E")
    elif eye == "happy":
        px(g, ex - 1, cy, "E"); px(g, ex, cy - 1, "E"); px(g, ex + 1, cy, "E")
    elif eye == "wide":
        rect(g, ex - 1, cy - 1, ex, cy, "E")


def belly(g, y0):
    for y in range(y0, S):
        for x in range(S):
            if g[y][x] == "F":
                g[y][x] = "B"


def stand(lift=(0, 0, 0, 0), bob=0, tail=0, eye="open"):
    """lift = (back near, back far, front near, front far) in px."""
    g = grid()
    bn, bf, fn, ff = lift
    rect(g, 11 + (bf > 0), 23, 12 + (bf > 0), 28 - bf, "S")
    rect(g, 21 + (ff > 0), 23, 22 + (ff > 0), 28 - ff, "S")
    ellipse(g, 14, 20 + bob, 8, 4.5, "F")
    belly(g, 23 + bob)
    for x, y in ((6, 18), (5, 17), (4, 16), (4, 15), (3 + tail, 14), (3 + tail, 13), (4 + tail, 12)):
        px(g, x, y + bob, "F" if y > 13 else "S")
    rect(g, 8 + (bn > 0), 23, 9 + (bn > 0), 28 - bn, "F")
    rect(g, 18 + (fn > 0), 23, 19 + (fn > 0), 28 - fn, "F")
    head(g, 23, 14 + bob, eye)
    outline(g)
    return g


def sit(tail=0, eye="open"):
    g = grid()
    for x, y in ((7, 27), (6, 27), (5, 27), (4, 27), (3, 26 - tail), (2, 25 - tail)):
        px(g, x, y, "F" if x > 3 else "S")
    ellipse(g, 13, 21.5, 6, 6.5, "F")
    rect(g, 9, 27, 13, 28, "B")       # haunch foot
    rect(g, 16, 20, 17, 28, "F")      # front legs
    rect(g, 19, 20, 20, 28, "S")
    rect(g, 15, 17, 17, 21, "B")      # chest
    head(g, 18, 11, eye)
    outline(g)
    return g


def sleep(f):
    g = grid()
    ry = 4 + 0.5 * (f in (1, 2))      # breathing
    ellipse(g, 14, 28.5 - ry, 10, ry, "F")
    rect(g, 7, 27, 16, 27, "S")       # tail wrapped around
    head(g, 21, 23, "closed")
    outline(g)
    zx, zy = 26 + f, 15 - 2 * f
    for dy, row in enumerate(("xxxx", "..x.", ".x..", "xxxx")):
        for dx, ch in enumerate(row):
            if ch == "x":
                px(g, zx - 1 + dx, zy + dy, "Z")
    return g


def petted(f):
    g = sit(tail=f % 2, eye="happy")
    for dy, row in enumerate((".x.x.", "xxxxx", ".xxx.", "..x..")):
        for dx, ch in enumerate(row):
            if ch == "x":
                px(g, 25 + dx, 5 - f + dy, "H")
    return g


def dangle(f, arms_up=False):
    g = grid()
    for x, y in ((12, 26), (11, 27), (10 + f, 28), (10 + f, 29)):
        px(g, x, y, "S")
    ellipse(g, 16, 18, 4.5, 8, "F")
    rect(g, 14, 15, 17, 23, "B")
    rect(g, 13 - f, 24, 14 - f, 29, "F")   # legs
    rect(g, 18 + f, 24, 19 + f, 29, "F")
    head(g, 16, 8, "wide")
    ax, ay = (8, 7) if arms_up else (10, 15)
    rect(g, ax, ay, ax + 1, ay + 4, "F")   # arms
    rect(g, 31 - ax, ay, 32 - ax, ay + 4, "F")
    outline(g)
    return g


ROWS = [
    ("idle",   [stand(), stand(tail=1), stand(), stand(tail=1, eye="closed")]),
    ("walk",   [stand((0, 2, 2, 0)), stand((0, 1, 1, 0), tail=1), stand(bob=1),
                stand((2, 0, 0, 2)), stand((1, 0, 0, 1), tail=1), stand(bob=1)]),
    ("sit",    [sit(), sit(tail=1)]),
    ("sleep",  [sleep(f) for f in range(4)]),
    ("petted", [petted(f) for f in range(4)]),
    ("held",   [dangle(0), dangle(1)]),
    ("fall",   [dangle(0, True), dangle(1, True)]),
]


def write_png(path, w, h, rgba):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))
    raw = b"".join(b"\0" + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                 + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def main():
    cols = max(len(frames) for _, frames in ROWS)
    w, h = cols * S, len(ROWS) * S
    buf = bytearray(w * h * 4)
    for r, (_, frames) in enumerate(ROWS):
        for c, g in enumerate(frames):
            for y in range(S):
                for x in range(S):
                    if g[y][x]:
                        i = ((r * S + y) * w + c * S + x) * 4
                        buf[i:i + 4] = bytes(PALETTE[g[y][x]]) + b"\xff"
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sprites", "cat.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    write_png(out, w, h, bytes(buf))
    print(f"wrote {os.path.normpath(out)} ({w}x{h})")


if __name__ == "__main__":
    main()

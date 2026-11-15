#!/usr/bin/env python3
"""Draws the cat sprite sheet (sprites/cat.png). Stdlib only.

Sheet: 32x32 frames, one row per animation, in the order of ROWS below.
Brain.js ANIMS must match the row order and frame counts.
Recolor by editing PALETTE and re-running.
"""
import os, struct, zlib

S = 32
PALETTE = {
    "O": (150, 88, 42),    # outline (dark shade of the fur, not black)
    "F": (245, 170, 80),   # fur
    "S": (214, 128, 52),   # stripes / far legs
    "B": (255, 246, 232),  # belly / muzzle / paws
    "E": (62, 42, 42),     # eyes
    "N": (245, 150, 160),  # nose, blush, inner ear
    "H": (229, 72, 77),    # heart
    "Z": (120, 150, 220),  # zzz
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
    return g


def over(base, top):
    """Paint an (outlined) layer on top of another, so parts keep their own outline."""
    for y in range(S):
        for x in range(S):
            if top[y][x]:
                base[y][x] = top[y][x]
    return base


def stamp(g, x0, y0, rows, c):
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch == "x":
                px(g, x0 + dx, y0 + dy, c)


def tail(g, points):
    """2px thick striped tail through the given points."""
    for i, (x, y) in enumerate(points):
        rect(g, x, y, x + 1, y, "S" if i % 3 == 2 else "F")


def head(cx, cy, eye="open"):
    """Small front-facing head, as its own outlined layer."""
    g = grid()
    ellipse(g, cx, cy, 7, 5.5, "F")
    for s in (-1, 1):                       # ears: sharp triangles, tip at the outer edge
        ox = cx + s * 6
        for i in range(4):
            rect(g, min(ox, ox - s * i), cy - 8 + i, max(ox, ox - s * i), cy - 8 + i, "F")
        px(g, ox - s, cy - 6, "N")
        rect(g, min(ox - s, ox - 2 * s), cy - 5, max(ox - s, ox - 2 * s), cy - 5, "N")
    for dx, n in ((-2, 2), (0, 3), (2, 2)):  # forehead stripes
        rect(g, cx + dx, cy - 5, cx + dx, cy - 6 + n, "S")
    ellipse(g, cx, cy + 3, 3, 2, "B")       # muzzle
    px(g, cx, cy + 1, "N")
    px(g, cx, cy + 2, "O")
    for s in (-1, 1):
        ex = cx + s * 4
        rect(g, min(ex, ex + s), cy + 3, max(ex, ex + s), cy + 3, "N")   # blush
        if eye == "open":
            rect(g, ex, cy, ex, cy + 1, "E")
        elif eye == "closed":
            rect(g, ex - 1, cy + 1, ex + 1, cy + 1, "E")
        elif eye == "happy":
            px(g, ex - 1, cy + 1, "E"); px(g, ex, cy, "E"); px(g, ex + 1, cy + 1, "E")
        elif eye == "wide":
            rect(g, min(ex, ex - s), cy, max(ex, ex - s), cy + 1, "E")
    return outline(g)


def stand(lift=(0, 0, 0, 0), bob=0, sway=0, eye="open"):
    """lift = (back near, back far, front near, front far) in px."""
    g = grid()
    bn, bf, fn, ff = lift
    rect(g, 11 + (bf > 0), 24, 12 + (bf > 0), 28 - bf, "S")
    rect(g, 20 + (ff > 0), 24, 21 + (ff > 0), 28 - ff, "S")
    ellipse(g, 13, 21 + bob, 8, 5, "F")
    for y in range(24 + bob, S):
        for x in range(S):
            if g[y][x] == "F":
                g[y][x] = "B"
    tail(g, [(4, 19 + bob), (3, 18 + bob), (2, 17 + bob), (2, 16 + bob), (2, 15 + bob),
             (2 + sway, 14 + bob), (3 + sway, 13 + bob)])
    for x, l in ((6 + (bn > 0), bn), (16 + (fn > 0), fn)):
        rect(g, x, 24, x + 2, 28 - l, "F")
        rect(g, x, 28 - l, x + 2, 28 - l, "B")
    return over(outline(g), head(21, 14 + bob, eye))


def sit(flick=0, eye="open"):
    g = grid()
    tail(g, [(9, 27), (7, 27), (6, 26), (5, 25), (4, 24), (4, 23 - flick), (5, 22 - flick)])
    ellipse(g, 16, 22.5, 6.5, 6, "F")
    ellipse(g, 16, 23, 3, 4, "B")
    rect(g, 12, 27, 14, 28, "B")
    rect(g, 18, 27, 20, 28, "B")
    return over(outline(g), head(16, 12, eye))


def sleep(f):
    """Lying loaf: long rounded back, head resting at the front, tail up at the back."""
    g = grid()
    top = 17 - (f in (1, 2))          # breathing
    tail(g, [(3, top + 2), (2, top + 1), (2, top), (1, top - 1), (1, top - 2), (1, top - 3)])
    ellipse(g, 12, 24, 9.5, 24 - top, "F")
    rect(g, 3, 24, 21, 28, "F")
    for y in range(29, S):            # flat on the floor
        rect(g, 0, y, S - 1, y, None)
    rect(g, 5, 27, 19, 28, "B")
    g = over(outline(g), head(22, 23, "closed"))
    rect(g, 11, 26, 13, 26, "B")      # tucked front paw: a small bump on the belly line
    rect(g, 11, 25, 13, 25, "O")
    px(g, 10, 26, "O")
    px(g, 10, 27, "O")
    stamp(g, 25 + f, 7 - 2 * f, ("xxxx", "..x.", ".x..", "xxxx"), "Z")
    return g


def petted(f):
    g = sit(flick=f % 2, eye="happy")
    stamp(g, 27, 5 - f, (".x.x.", "xxxxx", ".xxx.", "..x.."), "H")
    return g


def dangle(f, eye="open"):
    g = grid()
    tail(g, [(10, 26), (9, 27), (8 + f, 28), (8 + f, 29)])
    ellipse(g, 16, 21, 5, 7, "F")
    ellipse(g, 16, 22, 2.5, 4.5, "B")
    rect(g, 12 - f, 26, 13 - f, 30, "F")   # legs
    rect(g, 19 + f, 26, 20 + f, 30, "F")
    rect(g, 9, 19 - f, 11, 20 - f, "F")    # arms
    rect(g, 21, 19 - f, 23, 20 - f, "F")
    return over(outline(g), head(16, 11, eye))


ROWS = [
    ("idle",   [stand(), stand(sway=1), stand(), stand(sway=1, eye="closed")]),
    ("walk",   [stand((0, 2, 2, 0)), stand((0, 1, 1, 0), sway=1), stand(bob=1),
                stand((2, 0, 0, 2)), stand((1, 0, 0, 1), sway=1), stand(bob=1)]),
    ("sit",    [sit(), sit(flick=1)]),
    ("sleep",  [sleep(f) for f in range(4)]),
    ("petted", [petted(f) for f in range(4)]),
    ("held",   [dangle(0), dangle(1)]),
    ("fall",   [dangle(0, "wide"), dangle(1, "wide")]),
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

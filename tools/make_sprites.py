#!/usr/bin/env python3
"""Draws the pet sprite sheets (sprites/<species>-<coat>.png). Stdlib only.

Sheet: 32x32 frames, one row per animation, in the order of rows() below.
Brain.js ANIMS must match the row order and frame counts.
Every species shares the poses; SPECIES says how its head, tail and toy differ (STYLE)
and lists its coats. A coat overrides PALETTE colours and, under "style", STYLE entries.
Add a coat here and to the species' coats in Panel.qml.
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
    "Y": (125, 175, 235),  # yarn
    "y": (80, 120, 200),   # yarn strands
    "n": (40, 32, 36),     # dog nose
    "c": (214, 60, 70),    # dog collar
    "t": (250, 210, 80),   # collar tag
}

# How the species being drawn differs from the shared poses; main() sets it per sheet.
STYLE = {}
CAT_STYLE = {"ears": "pointed", "stripes": True, "face": "cat", "toy": "yarn", "spots": False}
DOG_STYLE = {"ears": "floppy", "stripes": False, "face": "dog", "toy": "ball", "spots": False,
             "tail": "whip", "mask": False}

CAT_COATS = {
    "orange": {},
    "grey":   {"O": (72, 74, 88), "F": (165, 170, 182), "S": (118, 122, 138), "B": (242, 242, 247)},
    "black":  {"O": (16, 14, 22), "F": (62, 60, 72), "S": (42, 40, 52), "B": (240, 240, 246),
               "E": (215, 225, 95)},
    "white":  {"O": (150, 150, 168), "F": (252, 252, 254), "S": (222, 224, 234), "B": (255, 255, 255)},
    "cream":  {"O": (172, 122, 80), "F": (250, 222, 172), "S": (236, 196, 140), "B": (255, 249, 238)},
}

# For a dog, S is the ears (and a Dalmatian's spots), Y/y the tennis ball.
DOG_BALL = {"Y": (200, 222, 70), "y": (250, 250, 240)}
DOG_COATS = {
    "golden":    {"O": (132, 80, 34), "F": (236, 184, 100), "S": (186, 122, 50), "B": (255, 240, 212),
                  "c": (70, 120, 210), "style": {"tail": "plume"}},
    "shiba":     {"O": (140, 74, 36), "F": (232, 140, 64), "S": (200, 106, 44), "B": (255, 246, 232),
                  "style": {"ears": "pointed", "tail": "curl", "mask": True}},
    "husky":     {"O": (58, 62, 78), "F": (130, 138, 156), "S": (92, 98, 116), "B": (250, 250, 253),
                  "style": {"ears": "pointed", "tail": "curl", "mask": True}},
    "dalmatian": {"O": (120, 120, 136), "F": (250, 250, 252), "S": (40, 38, 46), "B": (255, 255, 255),
                  "style": {"spots": True}},
    "chocolate": {"O": (52, 30, 20), "F": (118, 72, 46), "S": (86, 48, 30), "B": (176, 128, 92),
                  "E": (24, 14, 12), "n": (24, 14, 12), "c": (60, 170, 170)},
}

SPECIES = {
    "cat": {"style": CAT_STYLE, "palette": {}, "coats": CAT_COATS},
    "dog": {"style": DOG_STYLE, "palette": DOG_BALL, "coats": DOG_COATS},
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


def tail(g, points, wag=0):
    """Tail through the given points, base first. A cat's is long, thin and striped. A dog's is
    short: a thin whip, a feathered plume or a curl on the rump (STYLE["tail"]), wagging by `wag`."""
    if STYLE["face"] == "cat":
        for i, (x, y) in enumerate(points):
            rect(g, x, y, x + 1, y, "S" if i % 3 == 2 else "F")
        return
    # Drawn as one tapering piece from the base, in the direction the cat's tail sets off in:
    # thick where it joins the body, thin at the tip, the wag growing towards the tip.
    (bx, by), (ex, ey) = points[0], points[min(4, len(points) - 1)]
    dx, dy = ex - bx, ey - by
    n = max(abs(dx), abs(dy)) or 1
    ux, uy = dx / n, dy / n
    upright = abs(uy) >= abs(ux)
    if STYLE["tail"] == "curl" and uy < 0:
        cx, cy = bx + 2 + wag, by - 2
        ellipse(g, cx, cy, 3, 3, "F")
        rect(g, bx, by - 1, bx + 2, by, "F")          # joins the rump
        px(g, cx, cy, "S")                            # the hollow of the curl
        rect(g, cx - 1, cy - 2, cx, cy - 2, "B")
        return
    widths = (3, 3, 3, 2, 2, 1) if STYLE["tail"] == "plume" else (2, 2, 2, 1, 1, 1)
    for i, w in enumerate(widths):
        off = round(2 * wag * i / (len(widths) - 1))
        x, y = round(bx + i * ux), round(by + i * uy)
        if upright:
            x += off
            rect(g, x, y, x + w - 1, y, "F")
            if STYLE["tail"] == "plume" and w > 1:
                px(g, x, y, "S")                      # feathering on the back edge
        else:
            y -= off
            rect(g, x, y, x, y + w - 1, "F")
            if STYLE["tail"] == "plume" and w > 1:
                px(g, x, y + w - 1, "S")


def band(g, x0, y0, x1, y1, c):
    """Recolour what is already drawn inside the box: a collar follows the body's shape."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < S and 0 <= y < S and g[y][x]:
                g[y][x] = c


def collar(g, cx, y):
    """A dog's collar with its tag, on a body whose neck is centred on cx."""
    if STYLE["face"] == "dog":
        band(g, cx - 5, y, cx + 5, y + 1, "c")
        band(g, cx, y + 2, cx, y + 2, "t")


def ears(g, cx, cy, inner):
    """Ears on a head at (cx, cy): a cat's wide triangles, a dog's upright ones, or flaps down the sides."""
    for s in (-1, 1):
        if STYLE["ears"] == "floppy":
            ox = cx + s * 7
            rect(g, min(ox - s, ox - 3 * s), cy - 5, max(ox - s, ox - 3 * s), cy - 5, "S")
            rect(g, min(ox, ox - s), cy - 4, max(ox, ox - s), cy - 4, "S")
            rect(g, min(ox, ox + s), cy - 3, max(ox, ox + s), cy + 3, "S")
        elif STYLE["face"] == "dog":        # upright, tip in the middle of the ear
            ox = cx + s * 5
            px(g, ox, cy - 10, "F")
            rect(g, ox - 1, cy - 9, ox + 1, cy - 8, "F")
            rect(g, ox - 2, cy - 7, ox + 2, cy - 5, "F")
            rect(g, ox, cy - 8, ox, cy - 6, inner)
        else:
            ox = cx + s * 6                 # sharp triangles, tip at the outer edge
            for i in range(4):
                rect(g, min(ox, ox - s * i), cy - 8 + i, max(ox, ox - s * i), cy - 8 + i, "F")
            px(g, ox - s, cy - 6, inner)
            if inner == "N":
                rect(g, min(ox - s, ox - 2 * s), cy - 5, max(ox - s, ox - 2 * s), cy - 5, "N")


def head(cx, cy, eye="open"):
    """Small front-facing head, as its own outlined layer."""
    g = grid()
    ellipse(g, cx, cy, 7, 5.5, "F")
    dog = STYLE["face"] == "dog"
    ears(g, cx, cy, "S" if dog else "N")
    if STYLE["stripes"]:
        for dx, n in ((-2, 2), (0, 3), (2, 2)):  # forehead stripes
            rect(g, cx + dx, cy - 5, cx + dx, cy - 6 + n, "S")
    if dog:
        if STYLE["mask"]:                       # white cheeks and eyebrow dots
            m = grid()
            ellipse(m, cx, cy + 3, 6, 3.5, "B")
            for y in range(S):
                for x in range(S):
                    if m[y][x] and g[y][x] == "F":
                        g[y][x] = "B"
            for s in (-1, 1):
                px(g, cx + s * 4, cy - 2, "B")
        ellipse(g, cx, cy + 3, 4, 2.5, "B")     # broad muzzle
        rect(g, cx - 1, cy + 1, cx + 1, cy + 1, "n")
        px(g, cx, cy + 2, "n")
        if eye in ("open", "happy", "wide", "left", "right"):
            rect(g, cx, cy + 3, cx, cy + 4, "N")   # tongue out
    else:
        ellipse(g, cx, cy + 3, 3, 2, "B")       # muzzle
        px(g, cx, cy + 1, "N")
        px(g, cx, cy + 2, "O")
    for s in (-1, 1):
        ex = cx + s * 4
        if not dog:
            rect(g, min(ex, ex + s), cy + 3, max(ex, ex + s), cy + 3, "N")   # blush
        if eye == "open":
            rect(g, ex, cy, ex, cy + 1, "E")
        elif eye == "closed":
            rect(g, ex - 1, cy + 1, ex + 1, cy + 1, "E")
        elif eye == "happy":
            px(g, ex - 1, cy + 1, "E"); px(g, ex, cy, "E"); px(g, ex + 1, cy + 1, "E")
        elif eye == "wide":
            rect(g, min(ex, ex - s), cy, max(ex, ex - s), cy + 1, "E")
        elif eye in ("left", "right"):
            d = -1 if eye == "left" else 1
            rect(g, ex + d, cy, ex + d, cy + 1, "E")
    return outline(g)


def stand(lift=(0, 0, 0, 0), bob=0, sway=0, eye="open", head_at=None):
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
             (2 + sway, 14 + bob), (3 + sway, 13 + bob)], sway)
    for x, l in ((6 + (bn > 0), bn), (16 + (fn > 0), fn)):
        rect(g, x, 24, x + 2, 28 - l, "F")
        rect(g, x, 28 - l, x + 2, 28 - l, "B")
    hx, hy = head_at or (21, 14 + bob)
    return over(outline(g), head(hx, hy, eye))


def sit(flick=0, eye="open"):
    g = grid()
    tail(g, [(9, 27), (7, 27), (6, 26), (5, 25), (4, 24), (4, 23 - flick), (5, 22 - flick)], flick)
    ellipse(g, 16, 22.5, 6.5, 6, "F")
    ellipse(g, 16, 23, 3, 4, "B")
    collar(g, 16, 18)
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
    collar(g, 16, 17)
    return over(outline(g), head(16, 11, eye))


def back_head(cx, cy):
    """Back of the head: ears and tabby stripes, no face."""
    g = grid()
    ellipse(g, cx, cy, 7, 5.5, "F")
    ears(g, cx, cy, "S")                    # back of the ear
    if STYLE["stripes"]:
        for dx, top, bot in ((-3, -4, 1), (0, -5, 4), (3, -4, 1)):
            rect(g, cx + dx, cy + top, cx + dx, cy + bot, "S")
    return outline(g)


def climb(f):
    """Climbing up the window, back to the viewer: paws reach up in turn, legs push, tail swings."""
    up = f % 2
    sway = (0, 1, 0, -1)[f]
    g = grid()
    ellipse(g, 16, 17, 6, 7, "F")
    if STYLE["stripes"]:
        for y, half in ((13, 3), (16, 4), (19, 4), (22, 3)):  # tabby bands across the back
            rect(g, 16 - half, y, 16 + half, y, "S")
    g = outline(g)
    for x, lift in ((10, 2 * up), (20, 2 - 2 * up)):      # back legs push in turn
        leg = grid()
        rect(leg, x, 21 - lift, x + 2, 27 - lift, "F")
        rect(leg, x, 27 - lift, x + 2, 27 - lift, "B")
        g = over(g, outline(leg))
    for side, top in ((-1, 2 + 4 * up), (1, 6 - 4 * up)):  # arms, one reaching higher
        arm = grid()
        ax = 16 + side * 9
        rect(arm, min(ax, ax + side), top, max(ax, ax + side), 13, "F")
        rect(arm, min(ax, 16 + side * 6), 12, max(ax, 16 + side * 6), 13, "F")   # shoulder
        rect(arm, min(ax, ax + side), top, max(ax, ax + side), top + 1, "B")
        g = over(g, outline(arm))
    t = grid()
    tail(t, [(16, 23), (16, 24), (17, 25), (17 + sway, 26), (18 + sway, 27), (18 + sway, 28),
             (19 + 2 * sway, 29), (19 + 2 * sway, 30)])
    g = over(g, outline(t))
    return over(g, back_head(16, 8))


PEEK_EDGE = 10   # rows of the peek frame above the window edge; Service.qml clips the rest


def peek(eye="open"):
    """Peeking over a window's top edge: ears, eyes and paws. Rows from PEEK_EDGE down are behind the window."""
    g = head(16, 8, eye)
    for x in (3, 26):                       # paws gripping the edge
        p = grid()
        rect(p, x, PEEK_EDGE - 2, x + 2, PEEK_EDGE + 1, "B")
        g = over(g, outline(p))
    for y in range(PEEK_EDGE, S):
        rect(g, 0, y, S - 1, y, None)
    return g


def hang(swing=0, eye="open"):
    """Hanging by the front paws: paws at the very top of the frame, body dangling."""
    g = grid()
    for x in (7, 24):                       # arms come up from behind the head
        rect(g, x, 3, x + 1, 12, "F")
        rect(g, x - 1 + (x > 16), 1, x + 1 + (x > 16), 2, "B")   # paws on the edge
    tail(g, [(10, 26), (9, 27), (8 + swing, 28), (8 + swing, 29)])
    ellipse(g, 16, 21, 5, 7, "F")
    ellipse(g, 16, 22, 2.5, 4.5, "B")
    rect(g, 12 + swing, 26, 13 + swing, 30, "F")
    rect(g, 19 + swing, 26, 20 + swing, 30, "F")
    collar(g, 16, 17)
    return over(outline(g), head(16, 11, eye))


def crouch(wiggle=0):
    """Low hunting crouch, rear and tail wiggling, eyes locked on."""
    g = grid()
    tail(g, [(4, 22), (3, 21), (2, 20), (2 + wiggle, 19), (2 + wiggle, 18), (3 + wiggle, 17)])
    rect(g, 7 + wiggle, 26, 9 + wiggle, 28, "F")      # bent back leg
    rect(g, 11, 26, 12, 28, "S")
    rect(g, 20, 27, 21, 28, "S")
    ellipse(g, 13 + wiggle * 0.5, 24, 8, 3.5, "F")
    for y in range(26, S):
        for x in range(S):
            if g[y][x] == "F":
                g[y][x] = "B"
    rect(g, 17, 27, 19, 28, "B")                      # front paws flat
    return over(outline(g), head(22, 20, "wide"))


def pounce(f):
    """Airborne leap: stretched out, front paws reaching forward."""
    g = grid()
    tail(g, [(4, 17), (3, 16 + f), (2, 15 + f), (1, 15 + f), (0, 14 + f)])
    rect(g, 4, 22, 6, 23, "F")                        # back legs kicked back
    rect(g, 2, 23, 4, 24, "B")
    ellipse(g, 13, 19, 9, 4, "F")
    ellipse(g, 13, 21, 5, 1.5, "B")
    rect(g, 19, 22, 23, 23, "F")                      # front legs reaching
    rect(g, 23, 23 - f, 25, 24 - f, "B")
    return over(outline(g), head(22, 14, "wide"))


def paw(g, x0, y0, x1, y1):
    """A raised front leg on its own outlined layer, white toes at (x1, y1)."""
    p = grid()
    rect(p, x0, y0, x1, y1, "F")
    rect(p, x1 - 1, y1 - 1, x1, y1, "B")
    return over(g, outline(p))


def bat(f):
    """Standing, swatting forward with one front paw."""
    g = stand((0, 0, 4, 0), eye="wide")
    return paw(g, 24, 21, 28, 22) if f == 0 else paw(g, 24, 23, 28, 25)


def groom(f):
    """Sitting, licking a raised paw."""
    g = sit(eye="closed")
    g = paw(g, 18, 15 + f % 2, 20, 19)
    if f % 2:
        px(g, 17, 16, "N")                            # tongue
    return g


def stretch(f, eye="closed", wag=0):
    """Play-bow stretch after a nap: front down, rear up. Eyes open and wagging, it is a dog asking to play."""
    g = grid()
    up = f == 1
    tail(g, [(5, 16 - up), (4, 15 - up), (4, 14 - up), (4, 13 - up), (5, 12 - up)], wag)
    rect(g, 7, 20, 8, 28, "F")                        # back legs straight
    rect(g, 11, 20, 12, 28, "S")
    rect(g, 7, 28, 8, 28, "B")
    ellipse(g, 10, 19 - up, 5, 4, "F")
    ellipse(g, 17, 24, 7, 3, "F")
    rect(g, 17, 27, 28, 28, "F")                      # front legs stretched flat
    rect(g, 27, 27, 28, 28, "B")
    return over(outline(g), head(22, 22, eye))


def scratch(f):
    """Sitting, a hind leg up scratching behind the ear."""
    g = sit(eye="closed")
    leg = grid()
    top = 12 + f % 2
    rect(leg, 23, top, 24, 23, "F")
    rect(leg, 23, top, 24, top + 1, "B")
    return over(g, outline(leg))


def belly(f):
    """On his back for a belly rub: belly up, legs paddling in the air, a heart above."""
    g = grid()
    tail(g, [(4, 26), (3, 26), (2, 26), (1, 26), (0, 26)], f)
    ellipse(g, 13, 24, 9, 4, "F")
    ellipse(g, 13, 22.5, 6, 2, "B")
    for i, x in enumerate((7, 11, 15, 19)):
        top = 15 + 2 * ((i + f) % 2)
        rect(g, x, top, x + 1, 21, "F")
        rect(g, x, top, x + 1, top + 1, "B")
    for y in range(29, S):            # flat on the floor
        rect(g, 0, y, S - 1, y, None)
    g = over(outline(g), head(22, 22, "happy"))
    stamp(g, 26, 8 - f, (".x.x.", "xxxxx", ".xxx.", "..x.."), "H")
    return g


def sniff(f):
    """Walking with the nose along the ground."""
    lift = ((0, 2, 2, 0), (0, 0, 0, 0), (2, 0, 0, 2), (0, 0, 0, 0))[f]
    return stand(lift, sway=f % 2, eye="closed", head_at=(22, 20 + f % 2))


def bark(f):
    """Standing; on the bark the head snaps up, the mouth opens and two marks fly off."""
    if f == 0:
        return stand()
    g = stand(sway=1, eye="happy", head_at=(21, 13))
    rect(g, 20, 16, 22, 17, "E")
    px(g, 21, 17, "N")
    stamp(g, 24, 0, ("x..x..x", "x..x.x.", ".....x."), "Z")
    return g


def yawn(f):
    """Sitting with a big yawn."""
    g = sit(eye="closed")
    if f == 1:
        rect(g, 15, 14, 17, 16, "E")
        px(g, 16, 16, "N")
    else:
        rect(g, 15, 15, 17, 15, "E")
    return g


def yarn(f):
    """The toy in the top-left 12x12 of the frame: a ball of yarn, or a tennis ball with one seam; f rotates it."""
    g = grid()
    cos, sin = [(1, 0), (0.7, 0.7), (0, 1), (-0.7, 0.7)][f]
    if STYLE["toy"] == "ball":                        # smaller than yarn, resting on the cell's floor
        ellipse(g, 5.5, 6.5, 4, 4, "Y")
        for t in range(-4, 5):
            x, y = round(5.5 + t * cos), round(6.5 + t * sin)
            if g[y][x] == "Y":
                g[y][x] = "y"
        return outline(g)
    ellipse(g, 5.5, 5.5, 5, 5, "Y")
    for k in (-2, 0, 2):                              # three parallel strands
        for t in range(-5, 6):
            x, y = round(5.5 + t * cos - k * sin), round(5.5 + t * sin + k * cos)
            if g[y][x] == "Y":
                g[y][x] = "y"
    return outline(g)


def rows():
    """Every animation drawn in the current STYLE. A dog swaps two poses and adds rows at the end."""
    sheet = [
        ("idle",   [stand(), stand(sway=1), stand(), stand(sway=1, eye="closed")]),
        ("walk",   [stand((0, 2, 2, 0)), stand((0, 1, 1, 0), sway=1), stand(bob=1),
                    stand((2, 0, 0, 2)), stand((1, 0, 0, 1), sway=1), stand(bob=1)]),
        ("sit",    [sit(), sit(flick=1)]),
        ("sleep",  [sleep(f) for f in range(4)]),
        ("petted", [petted(f) for f in range(4)]),
        ("held",   [dangle(0), dangle(1)]),
        ("fall",   [dangle(0, "wide"), dangle(1, "wide")]),
        ("climb",  [climb(f) for f in range(4)]),
        ("peek",   [peek(e) for e in ("open", "left", "open", "right", "closed")]),
        ("crouch", [crouch(0), crouch(1)]),
        ("pounce", [pounce(0), pounce(1)]),
        ("bat",    [bat(0), bat(1)]),
        ("groom",  [groom(f) for f in range(4)]),
        ("stretch", [stretch(f) for f in range(3)]),
        ("yawn",   [yawn(f) for f in range(3)]),
        ("yarn",   [yarn(f) for f in range(4)]),
    ]
    if STYLE["face"] == "dog":
        swap = {"crouch": [stretch(1, "happy", 0), stretch(1, "happy", 1)],
                "groom": [scratch(f) for f in range(4)]}
        sheet = [(name, swap.get(name, frames)) for name, frames in sheet]
        sheet += [("sniff", [sniff(f) for f in range(4)]), ("bark", [bark(0), bark(1)]),
                  ("belly", [belly(0), belly(1)])]
    return sheet


def write_png(path, w, h, rgba):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))
    raw = b"".join(b"\0" + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                 + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def spotted(g):
    """Dalmatian spots: a fixed lattice of single dark pixels on the fur."""
    for y in range(S):
        for x in range(S):
            if g[y][x] == "F" and (x * 7 + y * 13) % 11 == 0:
                g[y][x] = "S"
    return g


def main():
    outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sprites")
    os.makedirs(outdir, exist_ok=True)
    for species, kind in SPECIES.items():
        for coat, overrides in kind["coats"].items():
            STYLE.clear()
            STYLE.update(kind["style"], **overrides.get("style", {}))
            sheet = rows()
            cols = max(len(frames) for _, frames in sheet)
            w, h = cols * S, len(sheet) * S
            pal = {**PALETTE, **kind["palette"], **{k: v for k, v in overrides.items() if k != "style"}}
            buf = bytearray(w * h * 4)
            for r, (name, frames) in enumerate(sheet):
                for c, g in enumerate(frames):
                    if STYLE["spots"] and name != "yarn":
                        spotted(g)
                    for y in range(S):
                        for x in range(S):
                            if g[y][x]:
                                i = ((r * S + y) * w + c * S + x) * 4
                                buf[i:i + 4] = bytes(pal[g[y][x]]) + b"\xff"
            out = os.path.normpath(os.path.join(outdir, f"{species}-{coat}.png"))
            write_png(out, w, h, bytes(buf))
            print(f"wrote {out} ({w}x{h})")


if __name__ == "__main__":
    main()

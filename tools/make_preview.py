#!/usr/bin/env python3
"""Compose the store preview (preview.png) from the real sprite sheets."""
import subprocess, sys

REPO = sys.argv[1]
OUT = sys.argv[2]
K = 6                      # pixel scale
W, H = 1600, 900
FONT = "JetBrainsMono-NF-Bold"
FONT_R = "JetBrainsMono-NF-Regular"
WIN = (110, 160, 1490, 700)   # mock window: left, top, right, bottom
ROWS = {"idle": 0, "walk": 1, "sit": 2, "sleep": 3, "petted": 4, "climb": 7, "peek": 8,
        "crouch": 9, "bat": 11, "yarn": 15, "ask": 16, "bubble": 19}

def frame(coat, row, col=0, w=32, h=32, flip=False, alpha=1.0):
    args = [f"(", f"{REPO}/sprites/cat-{coat}.png", "-crop", f"{w}x{h}+{col * 32}+{ROWS[row] * 32}", "+repage",
            "-filter", "point", "-resize", f"{K * 100}%"]
    if flip:
        args += ["-flop"]
    if alpha < 1:
        args += ["-channel", "A", "-evaluate", "multiply", str(alpha), "+channel"]
    return args + [")"]

def place(img_args, x, y):
    return img_args + ["-geometry", f"+{x}+{y}", "-composite"]

cmd = ["magick", "-size", f"{W}x{H}", "gradient:#1f2335-#16161e"]
# bar
cmd += ["-fill", "#1a1b26", "-draw", f"rectangle 0,0 {W},44"]
cmd += ["-font", FONT_R, "-pointsize", "22", "-fill", "#c0caf5",
        "-annotate", "+24+31", "  1  2  3", "-annotate", f"+{W // 2 - 40}+31", "Sunday 09:41"]
cmd += ["-pointsize", "26", "-annotate", f"+{W - 250}+33", "\U000F011B   \U000F00AF   \U000F05A9   \U000F02CB"]
# window
l, t, r, b = WIN
cmd += ["-fill", "#24283b", "-stroke", "#7aa2f7", "-strokewidth", "3",
        "-draw", f"roundrectangle {l},{t} {r},{b} 10,10", "-stroke", "none"]
cmd += ["-font", FONT, "-pointsize", "92", "-fill", "#c0caf5", "-annotate", f"+{l + 70}+{t + 150}", "Pixel Pets"]
cmd += ["-font", FONT_R, "-pointsize", "34", "-fill", "#a9b1d6",
        "-annotate", f"+{l + 74}+{t + 215}", "A pixel cat that lives on your Omarchy desktop"]
for i, (w, c) in enumerate([(560, "#414868"), (420, "#3b4261"), (500, "#414868"), (300, "#3b4261")]):
    y = t + 290 + i * 42
    cmd += ["-fill", c, "-draw", f"roundrectangle {l + 74},{y} {l + 74 + w},{y + 16} 8,8"]
# peeking over the window's top edge (orange); only rows above the edge show
cmd += place(frame("orange", "peek", 1, h=10), 1080, t - 10 * K)
# climbing the window, back view, see-through (grey)
cmd += place(frame("grey", "climb", 1, alpha=0.55), 1240, 330)
# floor
floor = H - 32 * K + 6
cmd += place(frame("black", "petted", 1), 90, floor)
tag_x, tag_y = 90 + 16 * K - 70, floor - 34
cmd += ["-fill", "#1e1e2ee6", "-stroke", "#966a3a", "-strokewidth", "2",
        "-draw", f"roundrectangle {tag_x},{tag_y} {tag_x + 140},{tag_y + 40} 6,6", "-stroke", "none",
        "-font", FONT, "-pointsize", "24", "-fill", "#fff6e8", "-annotate", f"+{tag_x + 33}+{tag_y + 29}", "Mochi"]
cmd += place(frame("cream", "crouch", 0), 380, floor)
cmd += place(frame("orange", "yarn", 0, w=12, h=12), 610, H - 12 * K)
# asking for water: care reminder bubble by her head
cmd += place(frame("grey", "ask", 1), 770, floor)
cmd += place(frame("grey", "bubble", 0, w=16, h=14), 770 + 21 * K, floor - 9 * K)
cmd += place(frame("white", "sleep", 1), 1060, floor)
cmd += place(frame("orange", "walk", 2, flip=True), 1330, floor)
cmd += [OUT]
subprocess.run(cmd, check=True)
print("wrote", OUT)

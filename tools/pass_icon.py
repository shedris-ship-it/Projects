"""The arcade pass's icon (512 x 512, for the owner to upload when making the
pass in Creator Hub): HOUSE CALL's attract screen as pixel art, drawn small
and blown up so its pixels stay square."""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1]
S = 128
img = Image.new("RGB", (S, S), (6, 6, 12))
d = ImageDraw.Draw(img)
BLUE = (70, 100, 255)
YOU = (250, 220, 40)
HIM = (236, 232, 222)
WHITE = (230, 230, 240)

# A cabinet's bezel round the screen.
d.rectangle((0, 0, S - 1, S - 1), outline=(150, 24, 30), width=4)
# The maze, in blue lines, the lower two thirds.
maze = [
    "##########",
    "#o...#..o#",
    "#.##.#.#.#",
    "#........#",
    "#.#.##.#.#",
    "#........#",
    "##########",
]
cell = 11
ox, oy = (S - len(maze[0]) * cell) // 2, 46
for y, row in enumerate(maze):
    for x, c in enumerate(row):
        px, py = ox + x * cell, oy + y * cell
        if c == "#":
            d.rectangle((px, py, px + cell - 1, py + cell - 1), fill=(18, 22, 70))
            for nx, ny, edge in ((x, y - 1, "t"), (x, y + 1, "b"), (x - 1, y, "l"), (x + 1, y, "r")):
                inside = 0 <= ny < len(maze) and 0 <= nx < len(row)
                if inside and maze[ny][nx] != "#":
                    if edge == "t":
                        d.line((px, py, px + cell - 1, py), fill=BLUE)
                    elif edge == "b":
                        d.line((px, py + cell - 1, px + cell - 1, py + cell - 1), fill=BLUE)
                    elif edge == "l":
                        d.line((px, py, px, py + cell - 1), fill=BLUE)
                    else:
                        d.line((px + cell - 1, py, px + cell - 1, py + cell - 1), fill=BLUE)
        elif c == ".":
            d.rectangle((px + 5, py + 5, px + 6, py + 6), fill=(226, 226, 236))
        elif c == "o":
            d.rectangle((px + 3, py + 3, px + 7, py + 7), fill=(255, 196, 90))
# You, your torch's line, and him frozen in it.
yx, yy = ox + 2 * cell + 5, oy + 3 * cell + 5
d.ellipse((yx - 4, yy - 4, yx + 4, yy + 4), fill=YOU)
d.rectangle((yx + 5, yy - 1, yx + 5 + 4 * cell, yy + 1), fill=(120, 110, 60))
hx = yx + 5 * cell
d.ellipse((hx - 5, yy - 5, hx + 5, yy + 5), fill=(150, 180, 255))
d.point((hx - 2, yy - 1), fill=(6, 6, 12))
d.point((hx + 2, yy - 1), fill=(6, 6, 12))

font = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 15)
small = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 10)


def centred(text, y, f, fill):
    w = d.textlength(text, font=f)
    d.text(((S - w) / 2, y), text, font=f, fill=fill)


centred("HOUSE CALL", 9, font, YOU)
centred("UNLIMITED PLAYS", 27, small, WHITE)
img = img.resize((512, 512), Image.NEAREST)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print("wrote", OUT)

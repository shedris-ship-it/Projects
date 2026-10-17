"""The starter pack's pass icon (512 x 512): a 1988 shop tag, the acid-wash
denim jacket on its hanger, 1,000 MARKS, on the boutique's paper."""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1]
S = 512
img = Image.new("RGB", (S, S), (150, 24, 30))
d = ImageDraw.Draw(img)
# The tag: cream card, a punched hole and its string.
d.rounded_rectangle((36, 36, S - 36, S - 36), radius=28, fill=(236, 228, 206))
d.ellipse((S / 2 - 16, 58, S / 2 + 16, 90), fill=(150, 24, 30))
d.line((S / 2, 58, S / 2 - 40, 0), fill=(230, 210, 150), width=5)
title = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 50)
big = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 50)
small = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 26)
ink = (40, 36, 36)


def centred(text, y, f, fill):
    w = d.textlength(text, font=f)
    d.text(((S - w) / 2, y), text, font=f, fill=fill)


centred("STARTER PACK", 100, title, ink)
# The jacket: an acid-wash blue, a collar, two chest pockets, buttons.
denim = (96, 120, 160)
pale = (150, 170, 200)
cx, top = S / 2, 180
hanger = [(cx - 70, top + 14), (cx, top - 14), (cx + 70, top + 14)]
d.line(hanger, fill=(120, 110, 100), width=6)
d.arc((cx - 14, top - 40, cx + 14, top - 12), 180, 360, fill=(120, 110, 100), width=5)
body = [(cx - 80, top + 10), (cx + 80, top + 10), (cx + 120, top + 40), (cx + 130, top + 150), (cx + 100, top + 152),
        (cx + 92, top + 70), (cx + 88, top + 170), (cx - 88, top + 170), (cx - 92, top + 70), (cx - 100, top + 152),
        (cx - 130, top + 150), (cx - 120, top + 40)]
d.polygon(body, fill=denim)
for (x0, y0, r) in ((cx - 50, top + 60, 18), (cx + 40, top + 110, 22), (cx - 20, top + 140, 14), (cx + 70, top + 40, 12)):
    d.ellipse((x0 - r, y0 - r, x0 + r, y0 + r), fill=pale)  # (the acid wash)
d.polygon([(cx - 80, top + 10), (cx - 30, top + 10), (cx, top + 60), (cx - 45, top + 45)], fill=(70, 92, 130))
d.polygon([(cx + 80, top + 10), (cx + 30, top + 10), (cx, top + 60), (cx + 45, top + 45)], fill=(70, 92, 130))
d.line((cx, top + 60, cx, top + 170), fill=(60, 80, 116), width=4)
for side in (-1, 1):
    d.rectangle((cx + side * 60 - 22, top + 72, cx + side * 60 + 22, top + 100), outline=(60, 80, 116), width=4)
for k in range(4):
    d.ellipse((cx + 8, top + 76 + k * 24, cx + 16, top + 84 + k * 24), fill=(200, 170, 90))
centred("+ 1,000 MARKS", 378, big, (150, 24, 30))
centred("ONCE PER INVESTIGATOR", 438, small, (110, 100, 90))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print("wrote", OUT)

#!/usr/bin/env python3
"""The menu's racer portraits, rendered from the 3D cast: Godot draws each
racer's head and shoulders lit as on character select (scenes/dev_portraits.tscn,
software rendering on the hidden display, see tools/shot.sh), then each is
set in a navy medallion with a gold rim and studs, like the N64 edition's
48px portraits, at CELL px: assets/images/portraits.png (one row).

Usage: python3 -I tools/make_portraits.py
"""
import math, os, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CELL = 192
SS = 4
NAVY, NAVY_D = (0x1C, 0x18, 0x40), (0x10, 0x0E, 0x28)
GOLD, GOLD_D, GOLD_L = (0xE8, 0xB0, 0x38), (0x9A, 0x6A, 0x14), (0xFF, 0xE4, 0x90)


def render(out):
    # through tools/shot.sh: software rendering on the hidden display, killed
    # if it ever opens the graphics chip
    env = dict(os.environ, SHOT_SCENE="res://scenes/dev_portraits.tscn")
    r = subprocess.run([os.path.join(ROOT, "tools", "shot.sh"), os.path.join(out, "log"), "9999", "", "--out=" + out],
                       env=env, timeout=600, capture_output=True, text=True)
    if "graphics chip" in r.stdout or "no X display" in r.stdout:
        sys.exit(r.stdout)


def medallion(racer):
    big = CELL * SS
    c = big / 2
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    R = big * 0.47  # outer rim
    ring = big * 0.075
    inner = R - ring
    # the disc: navy, lighter towards the top (a soft spotlight)
    disc = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    dd = ImageDraw.Draw(disc)
    for k in range(40, 0, -1):
        t = k / 40
        col = tuple(int(NAVY_D[j] + (NAVY[j] * 1.5 - NAVY_D[j]) * (1 - t) ** 1.5) for j in range(3))
        r = inner * t
        dd.ellipse([c - r, c - r * 1.05 - inner * 0.18 * (1 - t), c + r, c + r * 0.95 - inner * 0.18 * (1 - t)], fill=col + (255,))
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse([c - inner, c - inner, c + inner, c + inner], fill=255)
    img.paste(disc, (0, 0), mask)
    # the racer, cut to the disc but allowed over the rim at the top (hats, crowns)
    r = racer.resize((big, big), Image.LANCZOS)
    over = Image.new("L", (big, big), 0)
    od = ImageDraw.Draw(over)
    od.ellipse([c - inner, c - inner, c + inner, c + inner], fill=255)
    od.rectangle([0, 0, big, c - inner * 0.35], fill=255)
    a = Image.fromarray(np.minimum(np.asarray(r.getchannel("A")), np.asarray(over)))
    r.putalpha(a)
    # a soft shadow under the racer onto the disc
    sh = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    sh.putalpha(r.getchannel("A").filter(ImageFilter.GaussianBlur(big * 0.012)).point(lambda v: v * 0.45))
    disc_only = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    disc_only.paste(sh, (0, int(big * 0.012)), mask)
    img.alpha_composite(disc_only)
    # the rim: dark edge, gold band with a light top and a darker bottom, studs
    d = ImageDraw.Draw(img)
    d.ellipse([c - R, c - R, c + R, c + R], outline=GOLD_D + (255,), width=int(ring))
    d.ellipse([c - R + big * 0.008, c - R + big * 0.008, c + R - big * 0.008, c + R - big * 0.008], outline=GOLD + (255,), width=int(ring * 0.72))
    d.arc([c - R + ring * 0.3, c - R + ring * 0.3, c + R - ring * 0.3, c + R - ring * 0.3], 200, 340, fill=GOLD_L + (255,), width=int(ring * 0.22))
    d.ellipse([c - inner - 2 * SS, c - inner - 2 * SS, c + inner + 2 * SS, c + inner + 2 * SS], outline=GOLD_D + (255,), width=2 * SS)
    for k in range(4):
        ang = math.radians(k * 90)
        x, y = c + math.cos(ang) * (R - ring / 2), c + math.sin(ang) * (R - ring / 2)
        sr = ring * 0.62
        d.ellipse([x - sr, y - sr, x + sr, y + sr], fill=GOLD_D + (255,))
        d.ellipse([x - sr * 0.8, y - sr * 0.8, x + sr * 0.8, y + sr * 0.8], fill=GOLD + (255,))
        d.ellipse([x - sr * 0.5, y - sr * 0.65, x + sr * 0.1, y - sr * 0.05], fill=GOLD_L + (255,))
    img.alpha_composite(r)
    return img.resize((CELL, CELL), Image.LANCZOS)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        render(tmp)
        n = len([f for f in os.listdir(tmp) if f.startswith("r")])
        if n == 0:
            sys.exit("nothing rendered")
        sheet = Image.new("RGBA", (CELL * n, CELL), (0, 0, 0, 0))
        for i in range(n):
            sheet.paste(medallion(Image.open(os.path.join(tmp, "r%02d.png" % i)).convert("RGBA")), (i * CELL, 0))
    path = os.path.join(ROOT, "assets", "images", "portraits.png")
    sheet.save(path, optimize=True)
    print(f"{path}: {n} portraits at {CELL}px")


if __name__ == "__main__":
    main()

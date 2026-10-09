#!/usr/bin/env python3
"""The scenery as sculpted clay, in the cast's style: soft shapes melted
together (the N64 edition's Scene API in tools/characters.py there), meshed
by tools/make_models.py into assets/models/props/NAME.glb.

Sizes are in world units, matching the stand-ins in scripts/props.gd
(a pine is about 95 tall; the road is 300 wide). props(Scene) returns
{name: (scene, cell)}: `cell` is the meshing grid, coarser for big pieces.
"""
import math


def C(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)


BARK, PINE_G, PINE_D, SNOW = C(0x6A4428), C(0x2F6A38), C(0x22502C), C(0xEEF4FA)
STONE, STONE_D, ROOF, ROOF_D = C(0xA8A6B4), C(0x7E7C8C), C(0x5A3E7A), C(0x46305E)
WOOD, WOOD_D, GOLD, RED = C(0x8A5A30), C(0x5E3A1E), C(0xF0B838), C(0xA82838)
CREAM, IRON, FLAME, LEAF = C(0xF2E6C8), C(0x3E3E48), C(0xFFB040), C(0x4E8A3A)
GHOSTC, BONE, ICE, PETAL = C(0xC8FFE8), C(0xEDE4CC), C(0xCFE2F2), C(0xE87AB0)
WINDOW = C(0xFFD27A)


def pine(s, snow=False):
    s.group()
    s.cone((0, 0, 0), (0, 26, 0), 5.5, 4, BARK, k=2)
    s.group()
    for i, (y, r) in enumerate([(26, 30), (48, 24), (68, 17), (85, 10)]):
        s.cone((0, y, 0), (0, y + 22, 0), r, 1.5, PINE_G if i % 2 == 0 else PINE_D, k=4)
    if snow:
        s.group()
        for y, r in [(30, 26), (52, 20), (72, 13)]:
            s.ell((0, y + 6, 0), (r * 0.9, 3.5, r * 0.9), SNOW, k=3)
        s.sphere((0, 96, 0), 5, SNOW, k=2)


def tower(s, h=170, r=40, roof=ROOF):
    s.group()
    s.cyl((0, h / 2, 0), r, h, STONE, rnd=3)
    for a in range(8):  # stone courses
        t = a * math.pi / 4
        s.box((math.cos(t) * (r + 3), h - 6, math.sin(t) * (r + 3)), (6, 7, 6), STONE_D, rad=1.5)
    for y in (h * 0.35, h * 0.65):  # lit windows
        s.box((0, y, r - 1), (5, 9, 3), WINDOW, rad=2, emit=0.5)
    s.group()
    s.cone((0, h - 2, 0), (0, h + 70, 0), r + 10, 2, roof, k=2)
    s.cone((0, h + 70, 0), (0, h + 90, 0), 1.2, 0.8, IRON)
    s.box((5, h + 86, 0), (6, 4, 0.8), RED, rad=0.5)


def torch(s):
    s.group()
    s.cone((0, 0, 0), (0, 48, 0), 3, 2.2, WOOD_D, k=1)
    s.cyl((0, 50, 0), 5, 6, IRON, rnd=1)
    s.group()
    s.cone((0, 52, 0), (0, 68, 0), 5.5, 0.5, FLAME, k=3, emit=0.9)
    s.sphere((0, 56, 0), 4, C(0xFFE080), k=2, emit=1.0)


def banner(s):
    s.group()
    s.cone((0, 0, 0), (0, 92, 0), 2.2, 1.8, WOOD_D)
    s.sphere((0, 93, 0), 3.5, GOLD, shine=0.8)
    s.group()
    s.box((22, 66, 0), (20, 24, 0.8), RED, rad=0.6)
    s.cone((22, 42, 0), (12, 34, 0), 9, 0.5, RED, k=3)
    s.cone((22, 42, 0), (32, 34, 0), 9, 0.5, RED, k=3)
    s.ell((22, 68, 1), (7, 8, 1.2), GOLD, k=1, shine=0.7)  # the crest


def table(s):
    s.group()
    s.box((0, 30, 0), (60, 3, 32), WOOD, rad=2)
    for x in (-52, 52):
        for z in (-24, 24):
            s.cone((x, 0, z), (x, 28, z), 3.5, 3, WOOD_D)
    s.group()
    s.box((0, 33.5, 0), (62, 0.8, 26), CREAM, rad=0.5)  # the cloth
    for x in (-30, 0, 30):
        s.cyl((x, 40, 0), 6, 12, GOLD, rnd=2, shine=0.8)  # goblets


def books(s):
    s.group()
    cols = [RED, C(0x2A4A8A), C(0x2E6A3A), C(0x7A3A8A), C(0xB0702A)]
    for i in range(5):
        s.box((math.sin(i) * 2, 4 + i * 7, 0), (16 - i, 3.2, 11 - i * 0.6), cols[i], rad=1)
        s.box((math.sin(i) * 2 + 0.5, 4 + i * 7, 0), (15.6 - i, 2.6, 10.8 - i * 0.6), CREAM, rad=0.8, k=0.2)


def bush(s, flowers=False):
    s.group()
    for x, y, z, r in [(0, 14, 0, 18), (14, 10, 4, 13), (-13, 11, -3, 14), (4, 22, -6, 12), (-5, 9, 12, 11)]:
        s.sphere((x, y, z), r, LEAF, k=6)
    if flowers:
        s.group()
        for i in range(10):
            t = i * 2.4
            s.sphere((math.cos(t) * 15, 16 + math.sin(i * 1.7) * 8, math.sin(t) * 15), 3.2, PETAL if i % 2 else CREAM, k=0.5)
    else:  # spy bush: a pair of eyes peering out
        s.group()
        for x in (-5, 5):
            s.sphere((x, 18, 16), 4, CREAM, k=0.5)
            s.sphere((x, 18, 19.2), 1.8, C(0x1C181E))


def barrel(s):
    s.group()
    s.ell((0, 20, 0), (15, 20, 15), WOOD, k=0)
    s.cyl((0, 20, 0), 14, 41, WOOD, rnd=4, k=3)
    for y in (6, 34):
        s.torus((0, y, 0), 15.2, 1.6, IRON, k=0.5)


def tomb(s):
    s.group()
    s.box((0, 4, 0), (28, 4, 16), STONE_D, rad=1.5)
    s.box((0, 26, -6), (20, 22, 5), STONE, rad=2)
    s.cyl((0, 48, -6), 20, 10, STONE, rnd=4, k=3)
    s.group()
    s.box((0, 36, -0.8), (2, 9, 0.8), STONE_D, rad=0.4)  # a carved cross
    s.box((0, 39, -0.8), (7, 2, 0.8), STONE_D, rad=0.4)


def icerock(s):
    s.group()
    for x, y, z, r in [(0, 14, 0, 22), (16, 9, 6, 13), (-14, 10, -5, 15), (4, 28, 2, 12)]:
        s.ell((x, y, z), (r, r * 0.85, r * 1.1), ICE, k=5, shine=0.7)


def skulls(s):
    s.group()
    s.ell((0, 6, 0), (34, 8, 26), C(0x6A5A44), k=3)  # the mound
    for i, (x, z) in enumerate([(-12, 4), (10, 6), (0, -8), (18, -6)]):
        s.group()
        s.sphere((x, 18, z), 8, BONE, k=0)
        s.ell((x, 13, z + 3), (5.5, 4, 5), BONE, k=2)
        for e in (-3, 3):
            s.sphere((x + e, 19, z + 7), 2.2, C(0x2A1A12), sub=True, k=0.8)


def ghost(s):
    s.group()
    s.sphere((0, 52, 0), 16, GHOSTC, k=0, emit=0.4)
    s.cone((0, 52, 0), (0, 14, 0), 15, 20, GHOSTC, k=8, emit=0.4)
    for x in (-12, 0, 12):
        s.sphere((x, 12, 0), 7, GHOSTC, k=5, emit=0.4)
    s.box((0, 66, 0), (12, 3, 10), GOLD, rad=1, k=1, shine=0.8)  # the dead king's crown
    for x in (-10, 0, 10):
        s.cone((x, 68, 0), (x, 76, 0), 2.6, 0.5, GOLD, k=1)
    s.group()
    for e in (-5, 5):
        s.sphere((e, 54, 14), 2.5, C(0x203040))


def chapel(s):
    s.group()
    s.box((0, 45, 0), (55, 45, 80), STONE, rad=3)
    s.group()
    s.box((0, 100, 0), (60, 4, 84), ROOF_D, rad=2)
    s.ell((0, 100, 0), (58, 26, 84), ROOF, k=2)
    s.group()
    s.box((0, 125, 70), (16, 40, 16), STONE, rad=2)
    s.cone((0, 160, 70), (0, 210, 70), 20, 1, ROOF, k=2)
    s.box((0, 216, 70), (1.2, 10, 1.2), GOLD)
    s.box((0, 219, 70), (5, 1.2, 1.2), GOLD)
    s.group()
    s.cyl((0, 62, 81), 16, 4, WINDOW, rnd=1, emit=0.6)  # the rose window
    s.box((0, 22, 81), (10, 22, 2), WOOD_D, rad=2)


def stage(s):
    s.group()
    s.box((0, 14, 0), (60, 14, 36), WOOD, rad=2)
    s.group()
    for x in (-58, 58):
        s.cone((x, 28, -30), (x, 108, -30), 4, 4, GOLD, shine=0.7)
    s.box((0, 108, -30), (62, 6, 4), GOLD, rad=1.5, shine=0.7)
    s.group()
    for x in (-40, 40):  # the curtains, swagged back
        s.ell((x, 70, -26), (18, 40, 4), RED, k=0)
    s.box((0, 98, -27), (56, 8, 3), RED, rad=2)


def ship(s):
    s.group()
    s.ell((0, 18, 0), (26, 18, 70), WOOD, k=0)
    s.box((0, 34, 0), (24, 4, 66), WOOD_D, rad=3, k=4)
    s.box((0, 42, -52), (22, 10, 16), WOOD, rad=3, k=2)  # the stern castle
    s.group()
    s.cone((0, 30, 4), (0, 150, 4), 3.5, 2, WOOD_D)
    s.box((0, 100, 6), (34, 34, 1.2), CREAM, rad=1)
    s.box((0, 152, 4), (12, 7, 0.6), C(0x1C181E), rad=0.4)  # the pirate flag
    s.sphere((0, 152, 4.6), 2.5, BONE)


def throne(s):
    s.group()
    s.box((0, 14, 0), (22, 14, 20), GOLD, rad=3, shine=0.8)
    s.box((0, 50, -16), (22, 36, 5), GOLD, rad=3, k=2, shine=0.8)
    s.sphere((0, 92, -16), 10, GOLD, k=4, shine=0.8)
    s.group()
    s.box((0, 29, 2), (18, 2.5, 16), RED, rad=2)
    s.box((0, 52, -10.5), (16, 28, 1.5), RED, rad=1.5)


def goblet(s):
    s.group()
    s.cyl((0, 1.5, 0), 9, 3, GOLD, rnd=1, shine=0.85)
    s.cone((0, 2, 0), (0, 18, 0), 2, 2, GOLD, shine=0.85)
    s.ell((0, 26, 0), (10, 11, 10), GOLD, k=2, shine=0.85)
    s.cyl((0, 34, 0), 8, 6, RED, rnd=1, sub=True, k=1)


def crown(s):
    s.group()
    s.cyl((0, 8, 0), 18, 16, GOLD, rnd=2, shine=0.85)
    s.cyl((0, 9, 0), 15, 20, GOLD, rnd=1, sub=True, k=1)
    for i in range(5):
        t = i * 2 * math.pi / 5
        s.cone((math.cos(t) * 16.5, 14, math.sin(t) * 16.5), (math.cos(t) * 16.5, 30, math.sin(t) * 16.5), 4, 1, GOLD, k=1.5)
        s.sphere((math.cos(t) * 16.5, 31, math.sin(t) * 16.5), 2.6, RED if i % 2 else C(0x2A60C0), shine=0.9)


def willow(s):
    s.group()
    s.cone((0, 0, 0), (0, 60, 0), 10, 6, BARK, k=3)
    s.group()
    s.ell((0, 72, 0), (44, 22, 44), LEAF, k=8)
    for i in range(9):
        t = i * 2 * math.pi / 9
        s.cone((math.cos(t) * 30, 70, math.sin(t) * 30), (math.cos(t) * 44, 18, math.sin(t) * 44), 10, 4, LEAF, k=8)


def hill(s):
    s.group()
    s.ell((0, 0, 0), (90, 45, 90), C(0x4E7A3E), k=0)


def castle(s):
    """Elsinore, in the middle of every loop."""
    s.group()  # the keep
    s.box((0, 110, 0), (210, 110, 150), STONE, rad=6)
    for x in range(-180, 181, 40):  # battlements
        for z in (-150, 150):
            s.box((x, 226, z), (12, 12, 8), STONE, rad=2)
    for i, x in enumerate(range(-150, 151, 60)):  # lit windows
        s.box((x, 150, 151), (8, 16, 2), WINDOW, rad=3, emit=0.6)
    s.box((0, 40, 151), (34, 40, 3), WOOD_D, rad=8)  # the gate
    for x in (-210, 210):
        for z in (-150, 150):
            s.push()
            s.translate(x, 0, z)
            tower(s, h=340, r=48)
            s.pop()
    s.push()
    s.translate(0, 0, 0)
    tower(s, h=440, r=62)
    s.pop()


def arras(s):
    """The tapestry Polonius hides behind."""
    s.group()
    s.cone((-46, 0, 0), (-46, 104, 0), 2.6, 2.2, WOOD_D)
    s.cone((46, 0, 0), (46, 104, 0), 2.6, 2.2, WOOD_D)
    s.cone((-48, 102, 0), (48, 102, 0), 2.4, 2.4, GOLD, shine=0.7)
    s.group()
    for i in range(6):  # heavy folds
        s.ell((-38 + i * 15.2, 56, (i % 2) * 2.5), (9.5, 44, 3.2), C(0x7A2848) if i % 2 else C(0x8E3058), k=4)
    s.box((0, 58, 3.5), (20, 22, 0.8), GOLD, rad=0.6, k=1)  # the woven crest
    s.group()
    s.box((10, 8, 3), (6, 7, 3), C(0x5A3A1E), rad=2)  # a pair of shoes peeking out
    s.box((-4, 8, 3), (6, 7, 3), C(0x5A3A1E), rad=2)


def portrait(s):
    """The two kings' pictures: an easel with a gilt frame."""
    s.group()
    s.cone((-18, 0, 6), (0, 90, 0), 2.2, 1.8, WOOD_D)
    s.cone((18, 0, 6), (0, 90, 0), 2.2, 1.8, WOOD_D)
    s.cone((0, 0, -16), (0, 80, 0), 2.2, 1.8, WOOD_D)
    s.group()
    s.box((0, 58, 3), (24, 30, 2.5), GOLD, rad=1.2, shine=0.8)
    s.box((0, 58, 4.5), (19.5, 25.5, 1.4), C(0x2C3A5A), rad=0.6, k=0.5)
    s.sphere((0, 64, 5.5), 7, C(0xF4CBA4), k=0.5)  # the old king
    s.box((0, 72, 5.8), (7, 2.5, 1), GOLD, rad=0.5)  # his crown
    s.ell((0, 48, 5.5), (12, 8, 1.2), RED, k=1)


def tent(s):
    s.group()
    s.cone((0, 0, 0), (0, 70, 0), 46, 4, CREAM, k=0)
    for i in range(8):
        t = i * math.pi / 4
        s.cone((math.cos(t) * 42, 2, math.sin(t) * 42), (0, 68, 0), 4, 2, RED if i % 2 else CREAM, k=3)
    s.group()
    s.cone((0, 66, 0), (0, 96, 0), 1.6, 1.2, WOOD_D)
    s.box((8, 92, 0), (8, 4.5, 0.6), C(0x2A4A8A), rad=0.4)
    s.box((0, 18, 44), (12, 18, 2), C(0x3A2010), rad=6, sub=True, k=1)  # the door flap


def swords(s):
    s.group()
    s.box((0, 4, 0), (22, 4, 10), STONE_D, rad=1.5)
    for d in (-1, 1):
        s.push()
        s.translate(0, 8, 0)
        s.rotate("z", d * 28)
        s.box((0, 34, 0), (2.8, 30, 1.6), C(0xD8DEE8), rad=0.8, shine=0.9)
        s.box((0, 4, 0), (9, 1.8, 2), GOLD, rad=0.6, shine=0.8)  # the guard
        s.cone((0, 3, 0), (0, -8, 0), 1.6, 1.6, WOOD_D)
        s.sphere((0, -10, 0), 2.4, GOLD, shine=0.8)
        s.pop()


def rooster(s):
    """The cock that crows and sends the ghost away."""
    s.group()
    s.cone((-5, 0, 0), (-4, 16, 0), 1.2, 1.2, GOLD)
    s.cone((5, 0, 0), (4, 16, 0), 1.2, 1.2, GOLD)
    s.ell((0, 26, 0), (11, 11, 15), C(0xC85A28), k=0)
    s.sphere((0, 38, 11), 7, C(0xC85A28), k=4)
    s.cone((0, 38, 17), (0, 37, 23), 2.4, 0.4, GOLD, k=0.5)  # beak
    s.group()
    for i in range(3):
        s.sphere((0, 45 + i * 0.5, 8 + i * 3.5), 3, RED, k=1.5)  # comb
    s.ell((0, 33, 17), (1.6, 3.5, 1.5), RED, k=0.5)  # wattle
    for e in (-1, 1):
        s.sphere((e * 4.2, 40, 15.5), 1.4, C(0x1C181E))
    s.group()
    for i, c in enumerate([C(0x2A4A3A), C(0x1C3A6A), C(0x2A4A3A)]):  # tail feathers
        s.ell((0, 34 + i * 4, -14 - i * 2), (2.5, 10, 4), c, k=2)


def worm(s):
    """The worm that goes through the guts of a beggar."""
    s.group()
    for i in range(7):
        x = i * 7 - 21
        s.sphere((x, 5 + math.sin(i * 0.9) * 3, math.cos(i * 0.9) * 4), 5.5 - abs(i - 3) * 0.3, C(0xD08A8A), k=3)
    s.group()
    for e in (-1, 1):
        s.sphere((24, 9, e * 2.4), 1.3, C(0x1C181E))


def letter(s):
    s.group()
    s.box((0, 2, 0), (22, 1.2, 15), CREAM, rad=0.6)
    s.cone((-21, 3, -14), (0, 3.4, 0), 1, 0.5, C(0xD8CCB0), k=1.2)
    s.cone((21, 3, -14), (0, 3.4, 0), 1, 0.5, C(0xD8CCB0), k=1.2)
    s.cyl((0, 4, 0), 4.5, 2, RED, rnd=0.8, shine=0.6)  # the royal seal


def censer(s):
    s.group()
    s.cone((0, 0, 0), (0, 70, 0), 1.4, 1.4, IRON)
    s.cone((0, 70, 0), (18, 74, 0), 1.2, 1.2, IRON, k=1)
    s.cone((18, 74, 0), (18, 56, 0), 0.5, 0.5, GOLD)
    s.ell((18, 50, 0), (7, 6, 7), GOLD, k=1, shine=0.85)
    s.cone((18, 54, 0), (18, 60, 0), 4, 1, GOLD, k=1.5, shine=0.85)
    s.group()
    s.sphere((18, 64, 0), 3, C(0xE8E4F0), k=0, emit=0.2)  # a wisp of incense
    s.sphere((16, 70, 1), 2.4, C(0xE8E4F0), k=2, emit=0.2)


ALL = {
    "ARRAS": (arras, 1.0), "PORTRAIT": (portrait, 0.7), "TENT": (tent, 1.2), "SWORDS": (swords, 0.5),
    "ROOSTER": (rooster, 0.5), "WORM": (worm, 0.4), "LETTER": (letter, 0.4), "CENSER": (censer, 0.5),
    "PINE": (pine, 0.9), "SNOWPINE": (lambda s: pine(s, True), 0.9), "TOWER": (tower, 1.6), "TORCH": (torch, 0.6),
    "BANNER": (banner, 0.8), "TABLE": (table, 0.9), "BOOKS": (books, 0.5), "SPYBUSH": (bush, 0.7),
    "FLOWERS": (lambda s: bush(s, True), 0.7), "BARREL": (barrel, 0.6), "TOMB": (tomb, 0.7), "ICEROCK": (icerock, 0.8),
    "SKULLS": (skulls, 0.6), "GHOST": (ghost, 0.7), "CHAPEL": (chapel, 1.8), "STAGE": (stage, 1.2), "SHIP": (ship, 1.4),
    "THRONE": (throne, 0.8), "GOBLET": (goblet, 0.5), "CROWN": (crown, 0.5), "WILLOW": (willow, 1.1), "HILL": (hill, 2.5),
    "CASTLE": (castle, 4.0),
}


def props(Scene):
    out = {}
    for name, (build, cell) in ALL.items():
        s = Scene()
        build(s)
        out[name] = (s, cell)
    return out

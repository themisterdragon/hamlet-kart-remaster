"""Kart parts for the garage (build your own kart), sculpted with the N64
edition's Scene (tools/characters.py there), meshed by tools/make_models.py:

  bodies  - the tub, cockpit, seat, steering wheel and engine, no wheels
  wheel   - one wheel (each design), centred, axle along x, hub cap on +x
  riders  - each character with no kart under them
  ornament- each character's hood ornament, on its own

Bodies are painted in key colours that the game's kart shader recolours
(scripts/cast.gd): pure green = paint, pure blue = trim, pure red = seat,
each shaded by brightness. Every body keeps the cockpit, seat and steering
wheel where the classic kart has them, so any rider fits any body.
Model space as in characters.py: facing +z, wheels on y = 0.
"""
import math

PAINT, TRIM, SEAT = (0, 200, 0), (0, 0, 200), (200, 0, 0)

# where each body's wheels go: (x, z) of the front and back axles' right-hand
# ends, and the wheel radius there (the wheel meshes are made 7.2 units tall)
WHEEL_R = 7.2


def _common(s, c, inner):
    """The cockpit everyone sits in: hollow, a lip, the seat back, the
    steering column and wheel. Call inside the body's group first."""
    s.box((0, 15.2, -4), (7.4, 4.2, 8.2), inner, rad=3.0, k=1.2, sub=True)


def _lip_seat_wheel(s, c):
    s.group()  # a lip round the cockpit
    s.box((0, 13.7, -4), (8.6, 0.55, 9.3), TRIM, rad=0.5, shine=0.9)
    s.box((0, 13.7, -4), (7.3, 1.2, 8.0), TRIM, rad=0.5, k=0.3, sub=True)
    s.group()  # seat back
    s.box((0, 17.2, -9.2), (6.2, 5.2, 1.6), SEAT, rad=1.5, shine=0.3)
    s.ell((0, 22, -9.4), (5.5, 1.6, 1.8), SEAT, k=1.2)
    s.group()  # steering column and wheel
    s.cone((0, 12, 6), (0, 17.5, 4), 0.8, 0.7, c.IRON, shine=0.7)
    s.push()
    s.translate(0, 18.3, 3.6)
    s.rotate("x", 60)
    s.torus((0, 0, 0), 3.3, 0.75, c.BLACK, shine=0.5)
    s.cyl((0, 0, 0), 1.0, 1.0, TRIM, rnd=0.4, shine=0.9)
    s.pop()


def _exhausts(s, c, z=-20.5, y=9.5):
    s.group()
    for x in (-1, 1):
        s.push()
        s.translate(x * 4.5, y, z)
        s.rotate("x", 90)
        s.cyl((0, 0, 0), 1.7, 4.5, c.SILVER, rnd=0.6, shine=0.95)
        s.cyl((0, -2.2, 0), 1.0, 1.4, c.BLACK, rnd=0.2, k=0.2, sub=True)
        s.pop()


def racer(s, c, fins=False):
    """The classic storybook racer (characters.py kart()) in key colours."""
    shade = c.shade
    s.group()
    s.box((0, 9.5, -1), (10, 4.2, 15.5), PAINT, rad=3.8, shine=0.55)
    s.ell((0, 9.0, 13), (8.2, 4.6, 9.5), PAINT, k=3.0, shine=0.55)
    s.ell((0, 11.5, 9), (6.5, 3.0, 7.5), shade(PAINT, 1.18), k=2.0, shine=0.6)
    for x in (-1, 1):
        s.box((x * 10.8, 7.8, -2.5), (3.4, 3.2, 9.5), PAINT, rad=2.6, k=2.2, shine=0.55)
        s.ell((x * 11.2, 8.2, 7.6), (3.0, 2.8, 3.4), shade(PAINT, 0.85), k=1.5)
    _common(s, c, shade(PAINT, 0.45))
    s.group()  # bumper
    s.cone((-7.5, 5.5, 20.5), (7.5, 5.5, 20.5), 1.7, 1.7, TRIM, shine=0.9)
    for x in (-1, 1):
        s.cone((x * 7.5, 5.5, 20.5), (x * 6.5, 7.5, 17), 1.2, 1.0, TRIM, k=1.0, shine=0.9)
    s.group()  # engine + spoiler
    s.box((0, 12.5, -16.5), (6.5, 3.0, 3.2), c.IRON, rad=1.5, shine=0.75)
    for x in (-3.2, 0, 3.2):
        s.box((x, 15.6, -16.5), (0.9, 0.6, 2.6), shade(c.IRON, 1.3), rad=0.4, k=0.4, shine=0.8)
    s.box((0, 19.8, -19.4), (12.5, 1.3, 3.2), shade(PAINT, 1.1), rad=1.0, shine=0.6)
    for x in (-1, 1):
        s.box((x * 8.5, 17, -18.5), (0.8, 2.6, 1.0), TRIM, rad=0.4, k=0.6, shine=0.9)
        s.box((x * 12.6, 18.6, -19.4), (0.8, 3.0, 3.6), TRIM, rad=0.4, k=0.3, shine=0.9)
    _exhausts(s, c)
    if fins:
        s.group()
        for x in (-1, 1):
            s.cone((x * 10.5, 11, -10), (x * 12, 19, -17), 1.4, 0.4, TRIM, shine=0.9)
    _lip_seat_wheel(s, c)


def coach(s, c):
    """A royal coach: a round-bellied carriage with scrolled gold rails,
    lanterns at the front and a crown on the back."""
    shade = c.shade
    s.group()
    s.ell((0, 11, -2), (11, 6.5, 15.5), PAINT, shine=0.6)
    s.ell((0, 8.5, 11), (8.5, 4.8, 9), PAINT, k=3.5, shine=0.6)
    s.ell((0, 7.5, -2), (10, 3.5, 14), shade(PAINT, 0.8), k=2.0)
    _common(s, c, shade(PAINT, 0.45))
    s.group()  # gold rails along the sides, curling up at each end
    for x in (-1, 1):
        s.cone((x * 11.3, 12.5, -12), (x * 11.3, 12.5, 9), 0.9, 0.9, TRIM, shine=0.9)
        for z, d in ((9, 1), (-12, -1)):
            s.push()
            s.translate(x * 11.3, 14.2, z + d * 1.2)
            s.rotate("z", 90)
            s.torus((0, 0, 0), 1.9, 0.7, TRIM, shine=0.9)
            s.pop()
    s.group()  # lanterns
    for x in (-1, 1):
        s.cyl((x * 8.5, 14.5, 15.5), 1.6, 3.0, c.WHITE, rnd=0.6, shine=0.6, emit=0.8)
        s.cone((x * 8.5, 16.2, 15.5), (x * 8.5, 18.0, 15.5), 2.0, 0.4, TRIM, k=0.3, shine=0.9)
        s.cyl((x * 8.5, 12.6, 15.5), 1.9, 0.8, TRIM, rnd=0.3, shine=0.9)
    s.group()  # the crown on the back
    s.cyl((0, 17.5, -16.5), 5.0, 3.0, TRIM, rnd=0.6, shine=0.95)
    s.cyl((0, 17.5, -16.5), 4.2, 4.0, SEAT, rnd=0.3, k=0.2, sub=True)
    for k in range(6):
        a = 2 * math.pi * k / 6
        x, z = math.sin(a) * 4.8, math.cos(a) * 4.8
        s.cone((x, 18.5, -16.5 + z), (x * 1.05, 22.5, -16.5 + z * 1.05), 1.2, 0.4, TRIM, k=0.4, shine=0.95)
    s.ell((0, 18.0, -16.5), (4.2, 1.8, 4.2), SEAT, shine=0.3)
    _exhausts(s, c, z=-18.5, y=8.5)
    _lip_seat_wheel(s, c)


def coffin(s, c):
    """The gravediggers' cart: a long six-sided box with brass handles and a
    spade for a spoiler."""
    shade = c.shade
    wood = c.C(0x6A4428)
    s.group()
    s.push()
    for a in (-1, 1):  # two boxes, turned a little each way, make the six sides
        s.push()
        s.rotate("y", a * 7)
        s.box((0, 10, -1), (9.2, 4.6, 17.5), PAINT, rad=1.4, shine=0.5)
        s.pop()
    s.pop()
    s.box((0, 13.8, -1), (9.6, 0.9, 17.8), shade(PAINT, 1.15), rad=0.6, k=0.6, shine=0.6)  # the lid's edge
    _common(s, c, shade(PAINT, 0.45))
    s.group()  # brass handles
    for x in (-1, 1):
        for z in (-10, -2, 6):
            s.push()
            s.translate(x * 11.2, 10, z)
            s.rotate("x", 90)
            s.torus((0, 0, 0), 1.7, 0.55, TRIM, shine=0.95)
            s.pop()
    s.group()  # nose plate
    s.box((0, 9.5, 18.6), (6.5, 3.4, 0.8), TRIM, rad=0.5, shine=0.9)
    s.group()  # the spade: a handle and a blade
    s.cone((0, 13, -14), (0, 21, -19), 0.8, 0.8, wood, shine=0.3)
    s.push()
    s.translate(0, 22.5, -20)
    s.rotate("x", -30)
    s.box((0, 0, 0), (5.5, 3.6, 0.5), c.IRON, rad=0.4, shine=0.8)
    s.pop()
    _exhausts(s, c, z=-19.5)
    _lip_seat_wheel(s, c)


def ship(s, c):
    """A little pirate ship (Act IV): a round hull with a pointed bow,
    portholes, and a mast with a sail for a spoiler."""
    shade = c.shade
    wood = c.C(0x7A4A2A)
    s.group()
    s.ell((0, 9.5, -1), (11, 5.8, 17), PAINT, shine=0.5)
    s.cone((0, 10, 10), (0, 12.5, 23), 7.5, 1.2, PAINT, k=3.0, shine=0.5)
    s.box((0, 17.5, 0), (14, 3, 26), PAINT, rad=0.5, sub=True)  # the deck
    _common(s, c, shade(PAINT, 0.45))
    for x in (-1, 1):  # portholes
        for z in (-8, 0, 8):
            s.sphere((x * 10.6, 10, z), 1.4, c.BLACK, k=0.3, sub=True)
    s.group()  # gunwale rail
    s.ell((0, 13.6, -1), (11.4, 1.0, 17.4), TRIM, shine=0.85)
    s.ell((0, 13.9, -1), (10.2, 1.6, 16.2), TRIM, k=0.3, sub=True)
    s.group()  # deck planks
    s.box((0, 13.2, -1), (10.4, 0.5, 16), wood, rad=0.3, shine=0.2)
    s.box((0, 15.2, -4), (7.4, 4.2, 8.2), wood, rad=3.0, k=0.8, sub=True)
    s.group()  # mast and sail
    s.cone((0, 13, -15), (0, 31, -15), 0.9, 0.7, wood, shine=0.3)
    s.box((0, 29.5, -15), (6.5, 0.5, 0.5), wood, rad=0.3, k=0.3)
    s.push()
    s.translate(0, 24.5, -15.5)
    s.box((0, 0, 0), (6.0, 4.5, 0.35), SEAT, rad=0.3, shine=0.2)
    s.pop()
    s.group()  # bowsprit
    s.cone((0, 12.5, 22), (0, 15, 28), 0.7, 0.4, wood, shine=0.3)
    _exhausts(s, c, z=-17.5, y=8)
    _lip_seat_wheel(s, c)


# name: (sculpt, front axle (x, z, radius), back axle (x, z, radius), ornament (y, z))
BODIES = {
    "racer": (racer, (14.2, 12.5, 6.0), (14.8, -12.5, 7.2)),
    "royal": (lambda s, c: racer(s, c, fins=True), (14.2, 12.5, 6.0), (14.8, -12.5, 7.2)),
    "coach": (coach, (13.6, 11.5, 6.4), (14.4, -11.5, 7.6)),
    "coffin": (coffin, (13.4, 12.5, 5.6), (13.8, -12.5, 6.4)),
    "ship": (ship, (13.6, 11.0, 5.8), (14.4, -11.5, 7.0)),
}


def tread(s, c):
    """Fat tyres with tread grooves, a rim in the trim colour, a hub cap."""
    r, w = WHEEL_R, 5.4
    s.group()
    s.push()
    s.rotate("z", 90)
    s.cyl((0, 0, 0), r, w, c.TYRE, rnd=2.0, shine=0.15)
    for k in range(10):
        s.push()
        s.rotate("y", k * 36)
        s.box((0, 0, r), (w * 0.6, 0.45, 0.7), c.shade(c.TYRE, 0.6), rad=0.2, k=0.2, sub=True)
        s.pop()
    s.cyl((0, 0, 0), r * 0.52, w + 0.4, TRIM, rnd=0.6, k=0.3, shine=0.85)
    s.sphere((0, -(w / 2 + 0.2), 0), r * 0.26, c.HUB, k=0.6, shine=0.9)
    s.pop()


def spoked(s, c):
    """Carriage wheels: an iron rim on wooden spokes round a hub."""
    r, w = WHEEL_R, 3.2
    wood = c.C(0x8A5A30)
    s.group()
    s.push()
    s.rotate("z", 90)
    s.torus((0, 0, 0), r - 1.1, 1.2, c.IRON, shine=0.7)
    s.torus((0, 0, 0), r - 2.4, 0.7, wood, k=0.4, shine=0.3)
    s.pop()
    s.group()
    for k in range(8):
        a = 2 * math.pi * k / 8
        s.cone((0, 0, 0), (0, math.cos(a) * (r - 2.2), math.sin(a) * (r - 2.2)), 0.75, 0.55, wood, shine=0.3)
    s.push()
    s.rotate("z", 90)
    s.cyl((0, 0, 0), 1.9, w + 1.2, TRIM, rnd=0.6, k=0.6, shine=0.9)
    s.pop()


def royal(s, c):
    """Slim white-wall tyres on gold-spoked rims."""
    r, w = WHEEL_R, 4.2
    s.group()
    s.push()
    s.rotate("z", 90)
    s.cyl((0, 0, 0), r, w, c.TYRE, rnd=1.6, shine=0.2)
    s.cyl((0, 0, 0), r * 0.78, w + 0.3, c.WHITE, rnd=0.5, k=0.2, shine=0.4)
    s.cyl((0, 0, 0), r * 0.6, w + 0.6, TRIM, rnd=0.5, k=0.2, shine=0.95)
    s.pop()
    s.group()
    for k in range(5):
        a = 2 * math.pi * k / 5
        s.cone((w / 2 + 0.5, 0, 0), (w / 2 + 0.3, math.cos(a) * r * 0.55, math.sin(a) * r * 0.55), 0.55, 0.45, c.shade(c.TYRE, 1.4), k=0.3, shine=0.6)
    s.sphere((w / 2 + 0.4, 0, 0), r * 0.2, TRIM, k=0.5, shine=0.95)


WHEELS = {"tread": tread, "spoked": spoked, "royal": royal}


def riders_and_ornaments(c):
    """Each character's rider (their sculpt with kart() skipped) and their
    hood ornament on its own, plus their own kart's colours."""
    riders, ornaments, colours = {}, {}, {}
    real = c.kart
    for i, build in enumerate(c.CAST):
        got = {}

        def no_kart(s, body, trim, seat, ornament=None, fins=False):
            got.update(body=body, trim=trim, seat=seat, ornament=ornament, fins=fins)
        c.kart = no_kart
        s = c.Scene()
        build(s)
        c.kart = real
        riders[i] = s
        if got.get("ornament"):
            o = c.Scene()
            o.group()
            got["ornament"](o)
            ornaments[i] = o
        colours[i] = got
    return riders, ornaments, colours

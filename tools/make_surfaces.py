#!/usr/bin/env python3
"""Paints the tracks' surface textures: the roads, the ground around them and
the barriers' finish, at 512x512 and tiling seamlessly, each with a normal map
so the light catches the stones, boards and ripples.

Usage: python3 -I tools/make_surfaces.py
Writes assets/images/surface/NAME.png (grey: tinted in the game by each
track's colours) and NAME_n.png (normal map, OpenGL/Godot convention).

Everything is drawn from seeded noise here, so the art is our own and the
same every run. Greys average 214/255 like the N64 textures they replace
(Track.TEX_MEAN), so the tracks keep their colours.
"""
import os
import numpy as np
from PIL import Image

N = 512
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "images", "surface")
MEAN = 214.0 / 255.0

yy, xx = np.mgrid[0:N, 0:N].astype(np.float64)


# ---------------------------------------------------------------- helpers

def smooth(t):
    return t * t * (3 - 2 * t)


def value_noise(rng, cells_x, cells_y=None):
    """Tiling value noise in 0..1 with cells_x x cells_y lattice cells."""
    cells_y = cells_y or cells_x
    g = rng.random((cells_y, cells_x))
    fx = xx / N * cells_x
    fy = yy / N * cells_y
    x0 = np.floor(fx).astype(int)
    y0 = np.floor(fy).astype(int)
    tx = smooth(fx - x0)
    ty = smooth(fy - y0)
    x0 %= cells_x
    y0 %= cells_y
    x1 = (x0 + 1) % cells_x
    y1 = (y0 + 1) % cells_y
    a = g[y0, x0] * (1 - tx) + g[y0, x1] * tx
    b = g[y1, x0] * (1 - tx) + g[y1, x1] * tx
    return a * (1 - ty) + b * ty


def fbm(rng, base=4, octaves=5, gain=0.5, aniso=1):
    """Fractal noise in roughly 0..1; aniso > 1 stretches it along x."""
    out = np.zeros((N, N))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        c = base * 2 ** o
        out += amp * value_noise(rng, max(1, c // aniso), c)
        total += amp
        amp *= gain
    return out / total


def voronoi(rng, n, jitter=0.8):
    """Jittered-grid Voronoi that wraps: F1, F2 (in pixels) and each pixel's cell id."""
    cell = N / n
    pts = []
    for j in range(n):
        for i in range(n):
            pts.append(((i + 0.5 + (rng.random() - 0.5) * jitter) * cell,
                        (j + 0.5 + (rng.random() - 0.5) * jitter) * cell))
    f1 = np.full((N, N), 1e9)
    f2 = np.full((N, N), 1e9)
    ids = np.zeros((N, N), int)
    for k, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dx = np.minimum(dx, N - dx)
        dy = np.abs(yy - py)
        dy = np.minimum(dy, N - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        ids = np.where(closer, k, ids)
        f1 = np.where(closer, d, f1)
    return f1, f2, ids, len(pts)


def blur(a, r=1):
    """Small wrap-around box blur."""
    out = a.copy()
    for _ in range(r):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5
    return out


def normal_map(h, strength):
    """Height (0..1) to an OpenGL-style normal map (green = up the image)."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    n = np.stack([-dx, dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).round().astype(np.uint8)


def save(name, albedo, height, strength, mean=MEAN):
    a = np.clip(albedo, 0, None)
    a = a * (mean / a.mean())
    a = np.clip(a, 0, 1)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((a * 255).round().astype(np.uint8), "L").save(os.path.join(OUT, name + ".png"), optimize=True)
    Image.fromarray(normal_map(height, strength), "RGB").save(os.path.join(OUT, name + "_n.png"), optimize=True)
    print(f"{name}: mean {a.mean() * 255:.0f}, range {a.min() * 255:.0f}-{a.max() * 255:.0f}")


# ---------------------------------------------------------------- roads

def cobbles():
    rng = np.random.default_rng(10)
    f1, f2, ids, n = voronoi(rng, 10, 0.7)
    r = f1 / (f1 + f2 + 1e-9) * 2  # 0 at a stone's middle, 1 on the joint
    stone_mask = smooth(np.clip((0.95 - r) / 0.07, 0, 1))
    dome = np.sqrt(np.clip(1 - (r / 0.95) ** 2, 0, 1))
    tone = rng.uniform(0.9, 1.08, n)[ids]
    grain = fbm(rng, 16, 4)
    wear = fbm(rng, 3, 3)
    stone = tone * (0.9 + 0.12 * grain) * (0.96 + 0.08 * wear) * (0.9 + 0.1 * dome)
    joint = 0.62 + 0.1 * grain
    albedo = joint + (stone - joint) * stone_mask
    height = dome * stone_mask + 0.06 * grain
    save("cobbles", albedo, height, 10)


def ashlar(rng, rows, min_w, max_w, gap=3.0):
    """Rows of rectangular slabs in running bond: distance to the nearest
    joint (px) and a slab id, tiling in both directions."""
    rh = N / rows
    dist = np.zeros((N, N))
    ids = np.zeros((N, N), int)
    k = 0
    for r in range(rows):
        # slab widths that add up to exactly N, starting at a random offset
        widths = []
        while sum(widths) < N - max_w:
            widths.append(rng.uniform(min_w, max_w))
        widths.append(N - sum(widths))
        start = rng.uniform(0, N)
        edges = (start + np.concatenate([[0], np.cumsum(widths)])) % N
        y0, y1 = int(round(r * rh)), int(round((r + 1) * rh))
        x = xx[y0:y1]
        y = yy[y0:y1]
        dv = np.minimum(y - r * rh, (r + 1) * rh - y)
        dh = np.full(x.shape, 1e9)
        for e in edges[:-1]:
            d = np.abs(x - e)
            d = np.minimum(d, N - d)
            dh = np.minimum(dh, d)
        dist[y0:y1] = np.minimum(dv, dh)
        rel = (x - start) % N
        slab = np.searchsorted(np.cumsum(widths), rel, side="right")
        ids[y0:y1] = k + slab
        k += len(widths)
    return dist, ids, k


def flagstones():
    rng = np.random.default_rng(11)
    dist, ids, n = ashlar(rng, 4, 90, 180)
    grain = fbm(rng, 12, 5)
    mottle = fbm(rng, 4, 3)
    tone = rng.uniform(0.86, 1.06, n)[ids]
    # a few hairline cracks: thin bands of a warped noise
    crack = np.abs(fbm(rng, 3, 4) - 0.5)
    crack = (1 - np.clip(crack / 0.005, 0, 1)) * 0.6
    crack *= fbm(rng, 2, 2) > 0.68
    joint = smooth(np.clip((dist - 1.5) / 3.0, 0, 1))
    slab = tone * (0.84 + 0.18 * grain) * (0.92 + 0.14 * mottle) * (1 - 0.35 * crack)
    albedo = 0.4 + (slab - 0.4) * joint
    bevel = np.clip(dist / 8.0, 0, 1)
    height = smooth(bevel) * 0.8 + 0.1 * grain - 0.15 * crack
    save("flagstones", albedo, height, 7)


def planks():
    rng = np.random.default_rng(12)
    rows = 8  # boards run across the road (along u); seams between them along v
    rh = N / rows
    row = (yy // rh).astype(int)
    fy = (yy % rh) / rh
    albedo = np.zeros((N, N))
    height = np.zeros((N, N))
    streak = fbm(rng, 4, 6, 0.6, aniso=16)
    fine = fbm(rng, 8, 4, 0.6, aniso=32)
    for r in range(rows):
        m = row == r
        tone = rng.uniform(0.84, 1.06)
        # board ends: one or two seams per board, tiling across
        ends = rng.uniform(0, N, rng.integers(1, 3))
        d_end = np.full((N, N), 1e9)
        for e in ends:
            d = np.abs(xx - e)
            d_end = np.minimum(d_end, np.minimum(d, N - d))
        warp = 14 * streak + 6 * np.sin(xx * 2 * np.pi / N * rng.integers(1, 3) + rng.uniform(0, 6))
        rings = np.sin((yy + warp + r * 7.3) * (2 * np.pi / rng.uniform(9, 14))) * 0.5 + 0.5
        wood = tone * (0.80 + 0.08 * rings + 0.16 * streak + 0.08 * fine)
        seam_y = np.minimum(fy, 1 - fy) * rh
        seam = smooth(np.clip(np.minimum(seam_y - 1.0, d_end - 1.0) / 2.5, 0, 1))
        board = wood
        h = seam * (0.85 + 0.05 * rings)
        if rng.random() < 0.5:  # a knot: a dark stretched oval
            kx, ky = rng.uniform(0, N), (r + rng.uniform(0.3, 0.7)) * rh
            dx = np.minimum(np.abs(xx - kx), N - np.abs(xx - kx)) / 10.0
            dy = (yy - ky) / 4.0
            knot = np.exp(-(dx * dx + dy * dy))
            board = board * (1 - 0.3 * knot)
            h = h - 0.08 * knot
        a = 0.32 + (board - 0.32) * seam
        # a pair of nails a little in from each board end
        for e in ends:
            for ny in (0.3, 0.7):
                for side in (-1, 1):
                    nx = (e + side * 8) % N
                    d = np.sqrt(np.minimum(np.abs(xx - nx), N - np.abs(xx - nx)) ** 2 + (yy - (r + ny) * rh) ** 2)
                    nail = np.clip(1.6 - d, 0, 1)
                    a = a * (1 - 0.5 * nail)
                    h = h + 0.15 * nail
        albedo[m] = a[m]
        height[m] = h[m]
    save("planks", albedo, height, 6)


def carpet():
    rng = np.random.default_rng(13)
    fibre = fbm(rng, 64, 2)
    soft = fbm(rng, 6, 3)
    # a woven diamond lattice, 4 repeats a tile, with a small rosette in each
    u = xx / N * 4
    v = yy / N * 4
    du = np.abs((u + v) % 1 - 0.5)
    dv = np.abs((u - v) % 1 - 0.5)
    lattice = np.clip(1 - np.minimum(du, dv) / 0.035, 0, 1)
    cu = (u % 1) - 0.5
    cv = (v % 1) - 0.5
    r = np.sqrt(cu * cu + cv * cv)
    ang = np.arctan2(cv, cu)
    rosette = np.clip(1 - np.abs(r - (0.13 + 0.04 * np.cos(4 * ang))) / 0.025, 0, 1)
    weave = 0.5 + 0.5 * np.sin(xx * np.pi / 2) * np.sin(yy * np.pi / 2)
    pattern = np.maximum(lattice, rosette)
    albedo = (0.88 + 0.06 * weave + 0.10 * fibre) * (0.95 + 0.08 * soft) * (1 - 0.22 * pattern)
    height = 0.5 * fibre + 0.2 * weave - 0.25 * pattern
    save("carpet", albedo, height, 2.5)


def earth(name="earth", seed=14, pebbles=True):
    rng = np.random.default_rng(seed)
    base = fbm(rng, 4, 6, 0.55)
    fine = fbm(rng, 32, 3)
    albedo = 0.72 + 0.40 * base + 0.12 * fine
    height = 0.6 * base + 0.25 * fine
    if pebbles:
        f1, f2, ids, n = voronoi(rng, 22, 1.0)
        size = rng.uniform(1.5, 4.0, n)[ids]
        keep = (rng.random(n) < 0.25)[ids]
        peb = smooth(np.clip(1.2 - f1 / size, 0, 1)) * keep
        shade = rng.uniform(0.85, 1.15, n)[ids]
        albedo = albedo * (1 - 0.7 * peb) + shade * albedo * 0.7 * peb
        height = height + 0.35 * peb
    # darker damp patches
    damp = smooth(np.clip((fbm(rng, 3, 4) - 0.45) / 0.2, 0, 1))
    albedo *= 1 - 0.12 * damp
    save(name, albedo, height, 3.5)


def sand():
    rng = np.random.default_rng(15)
    warp = fbm(rng, 3, 4)
    ripple = np.sin((yy + 60 * warp + 10 * np.sin(xx * 2 * np.pi / N * 2)) * (2 * np.pi / 22.0 * 1.0))
    ripple = 0.5 + 0.5 * np.sign(ripple) * np.abs(ripple) ** 0.7
    speck = value_noise(rng, 256)
    dark = (speck > 0.93) * 0.25
    bright = (speck < 0.05) * 0.15
    albedo = (0.92 + 0.08 * ripple + 0.06 * fbm(rng, 8, 3)) * (1 - dark) + bright
    height = 0.6 * ripple + 0.2 * speck
    save("sand", albedo, height, 2.5)


# ---------------------------------------------------------------- ground

def grass():
    rng = np.random.default_rng(20)
    clumps = fbm(rng, 4, 4)
    out = np.zeros((N, N))
    # thousands of short blades, drawn as soft dashes leaning every way
    blades = np.zeros((N, N))
    for _ in range(9000):
        x0, y0 = rng.uniform(0, N, 2)
        ang = rng.uniform(-0.9, 0.9) - np.pi / 2
        ln = rng.uniform(5, 11)
        b = rng.uniform(0.6, 1.0)
        for t in np.linspace(0, 1, int(ln)):
            px = int(x0 + np.cos(ang) * ln * t) % N
            py = int(y0 + np.sin(ang) * ln * t) % N
            blades[py, px] = max(blades[py, px], b * (0.6 + 0.4 * t))
    blades = blur(blades, 1)
    out = 0.70 + 0.30 * clumps + 0.45 * blades - 0.12 * fbm(rng, 24, 2)
    save("grass", out, 0.5 * blades + 0.3 * clumps, 4)


def snow():
    rng = np.random.default_rng(21)
    drift = fbm(rng, 3, 5, 0.55)
    fine = fbm(rng, 48, 2)
    sparkle = (value_noise(rng, 512) > 0.985) * 0.12
    albedo = 0.94 + 0.06 * drift + 0.03 * fine + sparkle
    save("snow", albedo, 0.8 * drift + 0.1 * fine, 3)


def water():
    rng = np.random.default_rng(22)
    f1, f2, _, _ = voronoi(rng, 7, 1.0)
    caustic = blur(np.clip(1 - (f2 - f1) / 10.0, 0, 1) ** 2, 2)
    swell = fbm(rng, 3, 4)
    ripple = np.sin((yy + 40 * swell) * 2 * np.pi / 32) * 0.5 + 0.5
    albedo = 0.9 + 0.08 * caustic + 0.08 * swell
    save("water", albedo, 0.5 * ripple + 0.4 * swell - 0.3 * caustic, 2)


def plaster():
    """The barriers' and curbs' finish: a soft painted grain, close to white
    so their colours stay true."""
    rng = np.random.default_rng(23)
    g = fbm(rng, 8, 5)
    brush = fbm(rng, 6, 4, aniso=6)
    albedo = 0.9 + 0.06 * g + 0.04 * brush
    save("plaster", albedo, 0.6 * g + 0.4 * brush, 2, mean=0.95)


def ashlar_stone():
    """Castle walls: dressed stone blocks in running bond, close to white so
    the sculpt's own stone colour shows through."""
    rng = np.random.default_rng(24)
    dist, ids, n = ashlar(rng, 8, 70, 140, 2.0)
    grain = fbm(rng, 16, 4)
    tone = rng.uniform(0.9, 1.04, n)[ids]
    face = tone * (0.93 + 0.07 * grain)
    joint = smooth(np.clip((dist - 1.0) / 2.5, 0, 1))
    albedo = 0.62 + (face - 0.62) * joint
    height = smooth(np.clip(dist / 6.0, 0, 1)) + 0.1 * grain
    save("ashlar", albedo, height, 6, mean=0.92)


def clouds():
    """Soft cloud cover for the sky (no normal map): white where there's cloud."""
    rng = np.random.default_rng(25)
    c = 0.6 * fbm(rng, 8, 5, 0.55) + 0.4 * fbm(rng, 4, 3)
    c = smooth(np.clip((c - 0.47) / 0.22, 0, 1))
    Image.fromarray((c * 255).round().astype(np.uint8), "L").save(os.path.join(OUT, "clouds.png"), optimize=True)
    print(f"clouds: cover {c.mean():.2f}")


if __name__ == "__main__":
    cobbles()
    flagstones()
    planks()
    carpet()
    earth()
    sand()
    grass()
    snow()
    water()
    plaster()
    ashlar_stone()
    clouds()

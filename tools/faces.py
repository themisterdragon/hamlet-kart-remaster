"""Painted faces for the riders. The N64 sculpts build eyes, brows and mouths
from tiny shapes that a mesh can't hold sharply, so for the remaster those
calls are caught (not sculpted) and the same features are painted instead:
crisp at any size, with each character's own eye colour, gaze, brows, lids,
lashes and mouth.

capture(c, build) runs one character's sculpt and returns its Scene and its
face; uv_mask() gives each mesh vertex its place on the face texture and
whether it's bare skin there (the paint goes on skin only: hair, beards,
spectacles and hands in front stay on top); paint() draws the texture.
"""
import math
import numpy as np
from PIL import Image, ImageDraw

SIZE = 512
SS = 4  # drawn this many times larger, then shrunk: smooth edges
SPAN = 1.2  # the texture covers +-SPAN head radii around the head's centre


def capture(c, build):
    """Build a character with eyes() and mouth() recorded instead of sculpted.
    Returns (scene, face) where face is None if they have no painted face."""
    real = c.head, c.eyes, c.mouth
    face = {}

    def head(s, centre, r=10.5, skin=c.SKIN, chin=1.0):
        face.update(centre=s.t + s.m @ np.array(centre, float), m=s.m.copy(), r=r, skin=skin)
        real[0](s, centre, r, skin, chin)

    def eyes(s, centre, r=10.5, **kw):
        face["eyes"] = kw

    def mouth(s, centre, r=10.5, kind="smile", lip=c.LIPS):
        face["mouth"] = dict(kind=kind, lip=lip)

    c.head, c.eyes, c.mouth = head, eyes, mouth
    try:
        s = c.Scene()
        build(s)
    finally:
        c.head, c.eyes, c.mouth = real
    if "eyes" not in face and build.__name__ == "ghost":
        return s, helm(c, s)
    return s, (face if "eyes" in face else None)


def helm(c, s):
    """The Ghost's closed helm: its visor slit, breathing slits and glowing
    eyes are cut and set into the sculpt far smaller than a mesh can hold, so
    they're taken out and painted on the helm instead (paint(): kind "helm")."""
    slot = (0x10, 0x20, 0x2A)
    shell = next(p for p in s.prims if p["type"] == c.SPHERE and p["p"][0] > 11)  # the great helm
    centre = shell["t"] - np.array([0, 0.5, 0])  # the head's place (H)
    feats = dict(visor=None, breaths=[], eyes=[])
    keep = []
    for p in s.prims:
        q = p["t"] - centre
        if p["sub"] and tuple(p["col"]) == slot:
            if p["p"][0] > 3:
                feats["visor"] = (q[0], q[1], p["p"][0], p["p"][1])
            else:
                feats["breaths"].append((q[0], q[1], p["p"][0], p["p"][1]))
        elif p["emit"] >= 1.0 and np.linalg.norm(q) < 12:
            feats["eyes"].append((q[0], q[1], p["p"][0], p["p"][1]))
            feats["glow"] = p["col"]
        else:
            keep.append(p)
    # groups numbered again without gaps (sdfmesh counts them in order)
    ids = {g: i for i, g in enumerate(sorted({p["group"] for p in keep}))}
    for p in keep:
        p["group"] = ids[p["group"]]
    s.prims = keep
    return dict(centre=centre, m=np.eye(3), r=shell["p"][0], skin=shell["col"], kind="helm", **feats)


def uv_mask(face, verts, nv):
    """Per vertex: (u, v) on the face texture (a projection from the front of
    the head) and 1 where the paint may go (bare skin, on the face's side of
    the head), else 0."""
    out = []
    if face is None:
        return [(0.0, 0.0, 0.0)] * nv
    c, m, r = face["centre"], face["m"], face["r"]
    skin = np.array(face["skin"], float) / 255
    for i in range(nv):
        v = verts[10 * i: 10 * i + 10]
        p = m.T @ (np.array(v[0:3]) - c)  # in the head's own frame
        u = 0.5 + p[0] / (2 * SPAN * r)
        w = 0.5 - p[1] / (2 * SPAN * r)
        bare = np.linalg.norm(np.array(v[6:9]) - skin) < 0.1
        ok = bare and p[2] > 0 and np.linalg.norm(p) < 1.3 * r
        out.append((u, w, 1.0 if ok else 0.0))
    return out


def _shade(col, k):
    return tuple(max(0, min(255, int(x * k))) for x in col)


def paint(face):
    """The face texture: RGBA, transparent where there's nothing painted."""
    big = SIZE * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = face["r"]
    skin = tuple(face["skin"])
    e = face["eyes"]
    unit = big / (2 * SPAN * r)  # pixels per world unit
    if face.get("kind") == "helm":
        return _paint_helm(face, img, d, unit, big)

    def P(x, y):  # head units (x right, y up, centre 0) to pixels
        return (big / 2 + x * unit, big / 2 - y * unit)

    def ellipse(x, y, rx, ry, fill, outline=None, width=0):
        a, b = P(x - rx, y + ry), P(x + rx, y - ry)
        d.ellipse([a, b], fill=fill, outline=outline, width=int(width))

    def curve(pts, width, fill):
        """A smooth stroke through pts (Catmull-Rom), with round ends."""
        dense = []
        for k in range(len(pts) - 1):
            p0 = pts[max(k - 1, 0)]
            p1, p2 = pts[k], pts[k + 1]
            p3 = pts[min(k + 2, len(pts) - 1)]
            for t in np.linspace(0, 1, 16, endpoint=False):
                t2, t3 = t * t, t * t * t
                dense.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                          + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
        dense.append(pts[-1])
        px = [P(*q) for q in dense]
        w = int(width * unit)
        d.line(px, fill=fill, width=w, joint="curve")
        for q in (px[0], px[-1]):
            d.ellipse([q[0] - w / 2, q[1] - w / 2, q[0] + w / 2, q[1] + w / 2], fill=fill)

    def tapered(pts, w0, w1, fill):
        """A stroke that thins from w0 to w1 (world units) along pts."""
        n = len(pts)
        left, right = [], []
        for k, (x, y) in enumerate(pts):
            a = pts[min(k + 1, n - 1)]
            b = pts[max(k - 1, 0)]
            dx, dy = a[0] - b[0], a[1] - b[1]
            ln = math.hypot(dx, dy) or 1
            nx, ny = -dy / ln, dx / ln
            w = (w0 + (w1 - w0) * k / (n - 1)) / 2
            left.append(P(x + nx * w, y + ny * w))
            right.append(P(x - nx * w, y - ny * w))
        d.polygon(left + right[::-1], fill=fill)
        for (x, y), w in ((pts[0], w0), (pts[-1], w1)):
            ellipse(x, y, w / 2, w / 2, fill)

    size = e.get("size", 1.22)
    spacing = e.get("spacing", 0.37)
    look = e.get("look", (0.0, 0.0))
    iris = tuple(e.get("iris", (0x3A, 0x2A, 0x20)))
    lid = e.get("lid", 0.0)
    ink = (42, 26, 18)
    lash_col = _shade(ink, 0.8)
    for x in (-1, 1):
        ex, ey = x * r * spacing, r * 0.04
        rx, ry = r * 0.165 * size, r * 0.225 * size
        # the eye: white with a soft shadow under the upper lid
        ellipse(ex, ey, rx, ry, (250, 248, 242, 255))
        ellipse(ex, ey + ry * 0.55, rx * 0.95, ry * 0.5, (226, 222, 220, 255))
        ellipse(ex, ey + ry * 0.1, rx * 0.95, ry * 0.8, (250, 248, 242, 255))
        # iris (darker rim, lighter below), pupil, two highlights
        px, py = ex + look[0] * r * 0.055, ey - r * 0.015 + look[1] * r * 0.05
        irx, iry = r * 0.115 * size, r * 0.155 * size
        ellipse(px, py, irx, iry, _shade(iris, 0.7) + (255,))
        ellipse(px, py - iry * 0.12, irx * 0.84, iry * 0.8, iris + (255,))
        ellipse(px, py - iry * 0.4, irx * 0.6, iry * 0.35, _shade(iris, 1.35) + (255,))
        ellipse(px, py, irx * 0.48, iry * 0.48, (22, 18, 24, 255))
        ellipse(px - irx * 0.38, py + iry * 0.42, irx * 0.3, iry * 0.26, (255, 255, 255, 255))
        ellipse(px + irx * 0.32, py - iry * 0.4, irx * 0.13, iry * 0.11, (255, 255, 255, 230))
        # heavy lids for the schemers: skin closes over the top of the eye,
        # along a gentle arc, with the lash line on its edge
        a, b = P(ex - rx, ey + ry), P(ex + rx, ey - ry)
        d.ellipse([a, b], outline=lash_col + (255,), width=int(r * 0.025 * unit))
        if lid > 0:
            cut = ey + ry * (1 - 1.1 * lid)
            arc = [(ex + t * rx * 1.08, cut + ry * 0.14 * (1 - t * t) - ry * 0.04) for t in np.linspace(-1, 1, 9)]
            d.polygon([P(*q) for q in arc] + [P(ex + rx * 1.3, ey + ry * 1.4), P(ex - rx * 1.3, ey + ry * 1.4)], fill=skin + (255,))
            tapered(arc if x > 0 else arc[::-1], r * 0.085, r * 0.05, lash_col + (255,))
        else:
            arc = [(ex + rx * math.cos(t), ey + ry * math.sin(t)) for t in np.linspace(math.radians(160), math.radians(15), 9)]
            if x < 0:
                arc = [(2 * ex - q[0], q[1]) for q in arc][::-1]
            tapered(arc, r * 0.05, r * 0.085, lash_col + (255,))
        if e.get("lashes"):
            for k, (t, ln) in enumerate(((25, 0.11), (8, 0.13), (-8, 0.1))):
                ang = math.radians(t)
                bx, by = ex + x * rx * math.cos(ang) * 0.98, ey + ry * math.sin(ang) * 0.98 + (0 if lid == 0 else 0)
                tapered([(bx, by), (bx + x * r * ln * 0.75, by + r * ln * 0.55)], r * 0.045, r * 0.012, lash_col + (255,))
        brow = e.get("brow")
        if brow:
            tilt = math.radians(e.get("tilt", 0.0))
            by = ey + r * 0.46
            L = r * 0.2
            pts = []
            for t in np.linspace(-1, 1, 7):
                lx, ly = t * L, -0.25 * L * t * t + 0.06 * L  # a gentle arch
                ca, sa = math.cos(x * tilt), math.sin(x * tilt)  # + tilt: inner ends down (cross)
                pts.append((ex + lx * ca - ly * sa, by + lx * sa + ly * ca))
            if x < 0:
                pts = pts[::-1]  # thick at the inner end, thin at the outer
            brow_c = tuple(brow) + (255,)
            tapered(pts, r * 0.12, r * 0.05, brow_c)
    # the mouth
    mo = face.get("mouth") or {"kind": "smile", "lip": (0x8E, 0x3A, 0x3A)}
    lip = tuple(mo["lip"])
    dark = _shade(lip, 0.55) + (255,)
    kind = mo["kind"]
    my = -r * 0.5
    if kind == "smile":
        curve([(-r * 0.22, my + r * 0.06), (-r * 0.1, my - r * 0.03), (r * 0.1, my - r * 0.03), (r * 0.22, my + r * 0.06)], r * 0.055, dark)
    elif kind == "grin":
        pts = [P(r * 0.26 * math.cos(t), my + 0.04 * r - r * 0.16 * math.sin(t)) for t in np.linspace(0, math.pi, 24)]
        d.polygon(pts, fill=dark)
        d.rectangle([P(-r * 0.2, my + 0.04 * r), P(r * 0.2, my - 0.02 * r)], fill=(250, 248, 242, 255))
    elif kind == "smirk":
        curve([(-r * 0.12, my - r * 0.01), (r * 0.06, my - r * 0.02), (r * 0.2, my + r * 0.05), (r * 0.25, my + r * 0.1)], r * 0.05, dark)
    elif kind == "o":
        ellipse(0, my, r * 0.085, r * 0.11, _shade(lip, 0.75) + (255,))
        ellipse(0, my - r * 0.01, r * 0.05, r * 0.07, (60, 24, 30, 255))
    elif kind == "flat":
        curve([(-r * 0.15, my + r * 0.005), (0, my - r * 0.01), (r * 0.15, my - r * 0.02)], r * 0.045, dark)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def _paint_helm(face, img, d, unit, big):
    """The Ghost's visor: a dark slit with a bevelled rim and two glowing eyes
    behind it, five breathing slits below. The eyes and their halo are the
    only bright greens, which Cast.face() makes glow."""
    def P(x, y):
        return (big / 2 + x * unit, big / 2 - y * unit)

    def slot(x, y, hx, hy, fill, rim):
        rr = min(hx, hy) * unit
        d.rounded_rectangle([P(x - hx - 0.25, y + hy + 0.25), P(x + hx + 0.25, y - hy - 0.25)], radius=rr + 0.25 * unit, fill=rim)
        d.rounded_rectangle([P(x - hx, y + hy), P(x + hx, y - hy)], radius=rr, fill=fill)
        # a soft inner shadow along the top edge
        d.rounded_rectangle([P(x - hx, y + hy), P(x + hx, y + hy * 0.35)], radius=rr, fill=(4, 10, 16, 255))

    rim = (0x5E, 0x86, 0x9A, 255)
    dark = (0x10, 0x20, 0x2A, 255)
    if face["visor"]:
        slot(*face["visor"], dark, rim)
    for b in face["breaths"]:
        slot(*b, dark, rim)
    glow = tuple(face.get("glow", (0x70, 0xFF, 0xD0)))
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    for x, y, rx, ry in face["eyes"]:
        for k, a in ((2.2, 70), (1.6, 120)):
            hd.ellipse([P(x - rx * k, y + ry * k), P(x + rx * k, y - ry * k)], fill=glow + (a,))
    from PIL import ImageFilter
    halo = halo.filter(ImageFilter.GaussianBlur(unit * 0.5))
    # the halo lights the slit only (it's behind the visor)
    vis = Image.new("L", img.size, 0)
    if face["visor"]:
        x, y, hx, hy = face["visor"]
        ImageDraw.Draw(vis).rounded_rectangle([P(x - hx, y + hy), P(x + hx, y - hy)], radius=min(hx, hy) * unit, fill=255)
    halo.putalpha(Image.fromarray((np.asarray(halo.getchannel("A"), float) * np.asarray(vis, float) / 255).astype(np.uint8)))
    img.alpha_composite(halo)
    d = ImageDraw.Draw(img)
    for x, y, rx, ry in face["eyes"]:
        d.ellipse([P(x - rx, y + ry), P(x + rx, y - ry)], fill=glow + (255,))
        d.ellipse([P(x - rx * 0.55, y + ry * 0.5), P(x + rx * 0.55, y - ry * 0.5)], fill=(235, 255, 248, 255))
    return img.resize((SIZE, SIZE), Image.LANCZOS)

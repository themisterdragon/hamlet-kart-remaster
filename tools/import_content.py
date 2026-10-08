#!/usr/bin/env python3
"""Bring the N64 edition's words and assets into the remaster.

Reads tools/content.py from a Hamlet Kart (N64) checkout and writes
data/content.json; runs its tools/make_data.py track builder and writes the
same 16 layouts to data/tracks.json (N64 units: road half width 150); then
copies the fonts, portraits, logo, emblem, kart sprite sheets, item icons and
road textures into assets/, the sound effects and voices into assets/sound/sfx,
and the music into assets/sound/music as Ogg Vorbis (ffmpeg), so the web
build stays small. (They are the N64's 22 kHz mixes for now.)

Usage: python3 -I tools/import_content.py [path to the N64 Hamlet Kart repo]
       (default: ../hamlet-kart-public)
"""
import importlib.util, json, os, shutil, subprocess, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "hamlet-kart-public"))

FONTS = ["Almendra-Bold.ttf", "Almendra-OFL.txt", "LilitaOne-Regular.ttf", "LilitaOne-OFL.txt",
         "Andika-Bold.ttf", "Andika-OFL.txt"]
IMAGES = ["portraits.png", "logo.png", "emblem.png", "title_bg.png"]
DIRS = ["karts", "items", "tex"]  # kart sprite sheets (32 angles), item icons, road textures


def load_content():
    spec = importlib.util.spec_from_file_location("hk_content", os.path.join(SRC, "tools", "content.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def load_tracks():
    """The N64 edition's own track builder, so both editions race the same roads."""
    sys.path.insert(0, os.path.join(SRC, "tools"))
    spec = importlib.util.spec_from_file_location("hk_make_data", os.path.join(SRC, "tools", "make_data.py"))
    md = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(md)
    hexs = lambda c: "#%06x" % c
    out = []
    for ti, sh in enumerate(md.SHAPES):
        samples, total, _, _ = md.build_track(ti, sh)
        t = {
            "points": [[round(v, 2) for v in p] for p in samples],
            "lap_len": round(total, 1),
            "theme": {k: (hexs(v) if isinstance(v, int) else list(v)) for k, v in sh["theme"].items()},
            "props": [{"prop": md.PROPS[p], "sample": s, "side": side, "dist": round(d, 1), "scale": round(sc, 3)}
                      for p, s, side, d, sc in md.place_props(sh, samples)],
            "hazards": [{"prop": h[0], "at": h[1], "speed": h[2], "phase": h[3]} for h in sh.get("hazards", [])],
            "split": None,
        }
        if "split" in sh:
            a, b, peak, _ = md.split_route(samples, sh["split"])
            t["split"] = {"a": a, "b": b, "peak": peak}
        out.append(t)
    if md.errors:
        sys.exit("the N64 track builder reported problems:\n  " + "\n  ".join(md.errors))
    return {"road_half": md.HALF_W, "shoulder": md.SHOULDER, "spacing": md.SPACING, "tracks": out}


def question(q):
    text, correct, *wrong = q
    return {"q": text, "answer": correct, "wrong": wrong}


def main():
    c = load_content()
    data = {
        "acts": c.ACTS,
        "tracks": [{
            "act": t["act"], "scenes": t["scenes"], "name": t["name"],
            "summary": t["summary"], "beats": t["beats"],
            "questions": [question(q) for q in t["questions"]],
        } for t in c.TRACKS],
        "characters": [{k: v for k, v in ch.items() if k != "voice"} for ch in c.CHARACTERS],
        "items": [{"name": n, "desc": d} for n, d in c.ITEMS],
        "wrong_lines": c.WRONG_LINES,
    }
    with open(os.path.join(ROOT, "data", "content.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
        f.write("\n")

    tracks = load_tracks()
    with open(os.path.join(ROOT, "data", "tracks.json"), "w", encoding="utf-8") as f:
        json.dump(tracks, f, separators=(",", ":"))
        f.write("\n")

    assets = os.path.join(SRC, "assets")
    for name in FONTS:
        shutil.copy2(os.path.join(assets, name), os.path.join(ROOT, "assets", "fonts", name))
    for name in IMAGES:
        shutil.copy2(os.path.join(assets, name), os.path.join(ROOT, "assets", "images", name))
    for sub in DIRS:
        dest = os.path.join(ROOT, "assets", "images", sub)
        shutil.rmtree(dest, ignore_errors=True)
        shutil.copytree(os.path.join(assets, sub), dest)
    sfx = os.path.join(ROOT, "assets", "sound", "sfx")
    shutil.rmtree(sfx, ignore_errors=True)
    shutil.copytree(os.path.join(assets, "sfx"), sfx)
    music = os.path.join(ROOT, "assets", "sound", "music")
    os.makedirs(music, exist_ok=True)
    for name in sorted(os.listdir(os.path.join(assets, "music"))):
        if name.endswith(".wav"):
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", os.path.join(assets, "music", name),
                            "-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", "4",
                            os.path.join(music, name[:-4] + ".ogg")], check=True)

    nq = sum(len(t["questions"]) for t in data["tracks"])
    print(f"{len(data['tracks'])} tracks, {nq} questions, {len(data['characters'])} characters, "
          f"{len(data['items'])} items -> data/content.json")


if __name__ == "__main__":
    main()

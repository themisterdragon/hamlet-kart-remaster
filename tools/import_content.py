#!/usr/bin/env python3
"""Bring the N64 edition's words and assets into the remaster.

Reads tools/content.py from a Hamlet Kart (N64) checkout and writes
data/content.json, then copies the fonts, portraits, logo and emblem into
assets/, and the music and sound effects into assets/audio/ (not committed:
they are 22 kHz N64 mixes, to be replaced by full-quality PC ones).

Usage: python3 -I tools/import_content.py [path to the N64 Hamlet Kart repo]
       (default: ../hamlet-kart-public)
"""
import importlib.util, json, os, shutil, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "hamlet-kart-public"))

FONTS = ["Almendra-Bold.ttf", "Almendra-OFL.txt", "LilitaOne-Regular.ttf", "LilitaOne-OFL.txt",
         "Andika-Bold.ttf", "Andika-OFL.txt"]
IMAGES = ["portraits.png", "logo.png", "emblem.png", "title_bg.png"]


def load_content():
    spec = importlib.util.spec_from_file_location("hk_content", os.path.join(SRC, "tools", "content.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


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

    assets = os.path.join(SRC, "assets")
    for name in FONTS:
        shutil.copy2(os.path.join(assets, name), os.path.join(ROOT, "assets", "fonts", name))
    for name in IMAGES:
        shutil.copy2(os.path.join(assets, name), os.path.join(ROOT, "assets", "images", name))
    for sub in ("music", "sfx"):
        dest = os.path.join(ROOT, "assets", "audio", sub)
        shutil.rmtree(dest, ignore_errors=True)
        shutil.copytree(os.path.join(assets, sub), dest)

    nq = sum(len(t["questions"]) for t in data["tracks"])
    print(f"{len(data['tracks'])} tracks, {nq} questions, {len(data['characters'])} characters, "
          f"{len(data['items'])} items -> data/content.json")


if __name__ == "__main__":
    main()

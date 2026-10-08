#!/usr/bin/env python3
"""The cast as 3D models: each character and kart from the N64 edition's
sculpts (tools/characters.py there), meshed by tools/sdfmesh and written as
assets/models/cNN.glb with vertex colours (the clay's own colours).

Usage: python3 -I tools/make_models.py [N64 repo] [cell size] [characters...]
       (default ../hamlet-kart-public, cell 0.4, all eight)
Model space: the kart faces +z, wheels on y = 0, in world units.
"""
import importlib.util, json, os, struct, subprocess, sys, tempfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "hamlet-kart-public"))
CELL = float(sys.argv[2]) if len(sys.argv) > 2 else 0.4
ONLY = [int(a) for a in sys.argv[3:]]
EXE = os.path.join(ROOT, "build", "sdfmesh")
OUT = os.path.join(ROOT, "assets", "models")


def build_tool():
    src = os.path.join(ROOT, "tools", "sdfmesh", "sdfmesh.c")
    if not os.path.exists(EXE) or os.path.getmtime(EXE) < os.path.getmtime(src):
        os.makedirs(os.path.dirname(EXE), exist_ok=True)
        subprocess.run(["gcc", "-O2", "-fopenmp", "-o", EXE, src, "-lm"], check=True)


def mesh(scene):
    with tempfile.TemporaryDirectory() as tmp:
        sc, out = os.path.join(tmp, "scene.txt"), os.path.join(tmp, "mesh.bin")
        scene.write(sc)
        subprocess.run([EXE, sc, out, str(CELL)], check=True)
        data = open(out, "rb").read()
    nv, nt = struct.unpack_from("<ii", data)
    verts = struct.unpack_from("<%df" % (10 * nv), data, 8)
    tris = struct.unpack_from("<%di" % (3 * nt), data, 8 + 40 * nv)
    return nv, nt, verts, tris


def write_glb(path, nv, nt, verts, tris):
    pos, nrm, col = bytearray(), bytearray(), bytearray()
    lo, hi = [1e9] * 3, [-1e9] * 3
    for i in range(nv):
        v = verts[10 * i: 10 * i + 10]
        pos += struct.pack("<3f", *v[0:3])
        nrm += struct.pack("<3f", *v[3:6])
        # the sculpt's sRGB palette as is: Godot's clay material reads it as sRGB (scripts/cast.gd)
        col += struct.pack("<4f", *v[6:9], 1.0)
        lo = [min(a, b) for a, b in zip(lo, v[0:3])]
        hi = [max(a, b) for a, b in zip(hi, v[0:3])]
    idx = struct.pack("<%dI" % (3 * nt), *tris)
    blobs = [pos, nrm, col, idx]
    offsets, buf = [], bytearray()
    for b in blobs:
        offsets.append(len(buf))
        buf += b
        buf += b"\0" * (-len(buf) % 4)
    gltf = {
        "asset": {"version": "2.0", "generator": "hamlet-kart-remaster make_models.py"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": os.path.splitext(os.path.basename(path))[0]}],
        "materials": [{"name": "clay", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.55}}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "COLOR_0": 2}, "indices": 3, "material": 0}]}],
        "buffers": [{"byteLength": len(buf)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": offsets[0], "byteLength": len(pos), "target": 34962},
            {"buffer": 0, "byteOffset": offsets[1], "byteLength": len(nrm), "target": 34962},
            {"buffer": 0, "byteOffset": offsets[2], "byteLength": len(col), "target": 34962},
            {"buffer": 0, "byteOffset": offsets[3], "byteLength": len(idx), "target": 34963},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": nv, "type": "VEC3", "min": lo, "max": hi},
            {"bufferView": 1, "componentType": 5126, "count": nv, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": nv, "type": "VEC4"},
            {"bufferView": 3, "componentType": 5125, "count": 3 * nt, "type": "SCALAR"},
        ],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(buf)))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(buf), b"BIN\0") + buf)


def main():
    build_tool()
    sys.path.insert(0, os.path.join(SRC, "tools"))
    spec = importlib.util.spec_from_file_location("hk_characters", os.path.join(SRC, "tools", "characters.py"))
    chars = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(chars)
    os.makedirs(OUT, exist_ok=True)
    for i, scene in chars.characters().items():
        if ONLY and i not in ONLY:
            continue
        nv, nt, verts, tris = mesh(scene)
        path = os.path.join(OUT, "c%02d.glb" % i)
        write_glb(path, nv, nt, verts, tris)
        print(f"{path}: {nv} vertices, {nt} triangles, {os.path.getsize(path) // 1024} KB")


if __name__ == "__main__":
    main()

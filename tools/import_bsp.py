#!/usr/bin/env python3
"""GoldSrc BSP v30 -> Roblox native geometry + OBJ. Python standard library only.

No original texture pixels, lightmaps, sounds or scripts are copied.
"""

import argparse
import collections
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SCALE = 1 / 16  # 72-unit GoldSrc player -> 4.5 Roblox studs
THICKNESS = 0.05
SKIP = {"sky", "aaatrigger", "origin", "null", "clip", "hint", "skip"}
MATERIALS = {
    "tile_white": ((221, 226, 222), 784),
    "tile_blue": ((64, 139, 191), 784),
    "tile_red": ((183, 76, 70), 784),
    "concrete": ((158, 163, 157), 816),
    "metal": ((140, 155, 161), 1088),
    "red_partition": ((157, 61, 57), 272),
    "blue_partition": ((52, 108, 160), 272),
    "glass": ((163, 209, 220), 1568),
    "water": ((37, 167, 191), 1568),
    "light": ((255, 245, 218), 288),
    "dark": ((35, 39, 43), 272),
    "wood": ((168, 126, 78), 512),
}


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(a, n):
    return tuple(x * n for x in a)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def length(a):
    return math.sqrt(dot(a, a))


def unit(a):
    return mul(a, 1 / length(a))


def position(v):
    # Right-handed conversion: GoldSrc Z up -> Roblox Y up.
    return (v[0] * SCALE, v[2] * SCALE, -v[1] * SCALE)


def polygon_normal(points):
    result = (0, 0, 0)
    for i in range(1, len(points) - 1):
        result = add(result, cross(sub(points[i], points[0]), sub(points[i+1], points[0])))
    return result


def material(name, entity):
    name = name.lower()
    if entity == "func_water":
        return "water"
    if "glass" in name or "window" in name:
        return "glass"
    if "light" in name:
        return "light"
    if name == "black":
        return "dark"
    if "crt" in name:
        return "wood"
    if "stall" in name:
        return "red_partition"
    if "locker" in name or "steel" in name or "shower" in name:
        return "metal"
    if "blue" in name:
        return "tile_blue"
    if "red" in name:
        return "tile_red"
    if any(s in name for s in ("tile", "floor", "white", "chair", "rules")):
        return "tile_white"
    return "concrete"


class BSP:
    def __init__(self, path):
        self.data = path.read_bytes()
        if len(self.data) < 124 or struct.unpack_from("<i", self.data)[0] != 30:
            raise ValueError("Expected GoldSrc BSP version 30")
        self.lumps = [struct.unpack_from("<ii", self.data, 4 + i * 8) for i in range(15)]
        for start, size in self.lumps:
            if start < 0 or size < 0 or start + size > len(self.data):
                raise ValueError("Invalid BSP lump bounds")
        self.vertices = self.records(3, "3f")
        self.planes = self.records(1, "4fi")
        self.texinfo = self.records(6, "8fii")
        self.faces = self.records(7, "HHiHH4Bi")
        self.edges = self.records(12, "HH")
        self.surfedges = [e[0] for e in self.records(13, "i")]
        self.models = self.records(14, "9f7i")
        raw = self.lump(0).decode("latin1")
        self.entities = [dict(re.findall(r'"([^"\n]*)"\s*"([^"\n]*)"', block))
                         for block in re.findall(r"\{([^}]*)\}", raw)]
        textures = self.lump(2)
        self.textures = []
        for i in range(struct.unpack_from("<i", textures)[0]):
            offset = struct.unpack_from("<i", textures, 4 + i * 4)[0]
            if offset < 0:
                self.textures.append((f"missing_{i}", 64, 64))
            else:
                name = textures[offset:offset+16].split(b"\0")[0].decode("latin1")
                w, h = struct.unpack_from("<II", textures, offset + 16)
                self.textures.append((name, max(w, 1), max(h, 1)))

    def lump(self, index):
        start, size = self.lumps[index]
        return self.data[start:start+size]

    def records(self, index, fmt):
        return list(struct.iter_unpack("<" + fmt, self.lump(index)))

    def surfaces(self):
        entities = {0: {"classname": "worldspawn"}}
        for entity in self.entities:
            model = entity.get("model", "")
            if model.startswith("*"):
                entities[int(model[1:])] = entity
        for model_id, model in enumerate(self.models):
            entity = entities.get(model_id, {})
            kind = entity.get("classname", "")
            if kind.startswith("trigger_") or kind in {"func_buyzone", "func_bomb_target"}:
                continue
            offset = tuple(map(float, entity.get("origin", "0 0 0").split()))
            for face_id in range(model[-2], model[-2] + model[-1]):
                face = self.faces[face_id]
                first, count, ti = face[2:5]
                info = self.texinfo[ti]
                name, width, height = self.textures[info[8]]
                if name.lower() in SKIP or count < 3:
                    continue
                points, uvs = [], []
                for se in self.surfedges[first:first+count]:
                    edge = self.edges[abs(se)]
                    v = self.vertices[edge[0] if se >= 0 else edge[1]]
                    points.append(position(add(v, offset)))
                    uvs.append(((dot(v, info[:3]) + info[3]) / width,
                                -(dot(v, info[4:7]) + info[7]) / height))
                if length(polygon_normal(points)) < 1e-8:
                    continue
                expected = position(self.planes[face[0]][:3])
                if face[1]:
                    expected = mul(expected, -1)
                if dot(polygon_normal(points), expected) < 0:
                    points.reverse()
                    uvs.reverse()
                # Water is represented by its top surface, not solid side walls.
                if kind == "func_water" and max(p[1] for p in points) - min(p[1] for p in points) > 1e-4:
                    continue
                if kind == "func_water" and abs(points[0][1] - model[5] * SCALE) > 1e-4:
                    continue
                yield face_id, model_id, name, kind, points, uvs


def prop(parent, tag, name, text):
    node = ET.SubElement(parent, tag, name=name)
    node.text = str(text)
    return node


def vector(parent, name, values):
    node = ET.SubElement(parent, "Vector3", name=name)
    for axis, value in zip("XYZ", values):
        ET.SubElement(node, axis).text = f"{value:.7g}"


class Scene:
    def __init__(self):
        self.root = ET.Element("roblox", version="4")
        self.model = ET.SubElement(self.root, "Item", {"class": "Model", "referent": "Map"})
        props = ET.SubElement(self.model, "Properties")
        prop(props, "string", "Name", "FyPoolDay")
        self.groups = {}
        self.counts = collections.Counter()

    def group(self, name):
        if name not in self.groups:
            node = ET.SubElement(self.model, "Item", {"class": "Folder"})
            prop(ET.SubElement(node, "Properties"), "string", "Name", name)
            self.groups[name] = node
        return self.groups[name]

    def part(self, group, name, center, size, mat, collide=True, basis=None, cls="Part", color=None):
        if min(size) < 1e-5:
            return
        self.counts[cls] += 1
        item = ET.SubElement(self.group(group), "Item", {"class": cls})
        props = ET.SubElement(item, "Properties")
        prop(props, "string", "Name", name)
        prop(props, "bool", "Anchored", "true")
        prop(props, "bool", "CanCollide", str(collide).lower())
        prop(props, "bool", "CanTouch", "false")
        prop(props, "bool", "CastShadow", str(mat not in {"water", "glass", "grout"}).lower())
        color_default, material_id = MATERIALS.get(mat, ((116, 127, 131), 272))
        rgb = color or color_default
        prop(props, "Color3uint8", "Color3uint8", 0xff000000 | rgb[0] << 16 | rgb[1] << 8 | rgb[2])
        prop(props, "token", "Material", material_id)
        prop(props, "token", "TopSurface", 0)
        prop(props, "token", "BottomSurface", 0)
        prop(props, "float", "Transparency", 0.4 if mat == "water" else 0.55 if mat == "glass" else 0)
        vector(props, "size", tuple(max(0.001, v) for v in size))
        frame = ET.SubElement(props, "CoordinateFrame", name="CFrame")
        for axis, value in zip("XYZ", center):
            ET.SubElement(frame, axis).text = f"{value:.7g}"
        basis = basis or ((1, 0, 0), (0, 1, 0), (0, 0, 1))
        for row in range(3):
            for col in range(3):
                ET.SubElement(frame, f"R{row}{col}").text = f"{basis[col][row]:.9g}"
        if cls == "SpawnLocation":
            prop(props, "bool", "Neutral", "true")
            prop(props, "int", "Duration", 0)
            prop(props, "float", "Transparency", 1)
        return item

    def triangle(self, group, name, a, b, c, mat, collide):
        ab, ac, bc = sub(b, a), sub(c, a), sub(c, b)
        if dot(ab, ab) > max(dot(ac, ac), dot(bc, bc)):
            c, a = a, c
        elif dot(ac, ac) > max(dot(ab, ab), dot(bc, bc)):
            a, b = b, a
        ab, ac, bc = sub(b, a), sub(c, a), sub(c, b)
        if length(cross(ac, ab)) < 1e-8:
            return
        right = unit(cross(ac, ab))
        up = unit(cross(bc, right))
        back = unit(bc)
        height = abs(dot(ab, up))
        for suffix, end, leg, r, z in [("a", b, ab, right, back),
                                      ("b", c, ac, mul(right, -1), mul(back, -1))]:
            self.part(group, name + suffix, mul(add(a, end), 0.5),
                      (THICKNESS, height, abs(dot(leg, back))), mat, collide,
                      (r, up, z), "WedgePart")

    def surface(self, face_id, name, kind, points):
        mat = material(name, kind)
        collide = kind not in {"func_water", "func_illusionary"}
        group = "Water" if mat == "water" else "Geometry"
        low = tuple(min(p[i] for p in points) for i in range(3))
        high = tuple(max(p[i] for p in points) for i in range(3))
        size = sub(high, low)
        flat = [i for i in range(3) if size[i] < 1e-5]
        label = f"f{face_id}_{name}"
        # Only exact axis-aligned rectangular polygons become boxes.
        if len(flat) == 1:
            axes = [i for i in range(3) if i != flat[0]]
            area = sum(length(cross(sub(points[i], points[0]), sub(points[i+1], points[0]))) / 2
                       for i in range(1, len(points)-1))
            rectangle = abs(area - size[axes[0]] * size[axes[1]]) < 1e-4
        else:
            rectangle = False
        if rectangle:
            normal = unit(polygon_normal(points))
            center = sub(mul(add(low, high), 0.5), mul(normal, THICKNESS / 2))
            box = list(size)
            box[flat[0]] = THICKNESS
            self.part(group, label, center, box, mat, collide)
            # Procedural tile grout uses native geometry, no uploaded textures needed.
            if mat.startswith("tile_") and area > 2:
                for axis in axes:
                    step = 2.0
                    coord = (math.floor(low[axis] / step) + 1) * step
                    while coord < high[axis] - 0.02:
                        line_size = list(size)
                        line_size[axis] = 0.025
                        line_size[flat[0]] = 0.008
                        line_pos = list(add(mul(add(low, high), 0.5), mul(normal, 0.006)))
                        line_pos[axis] = coord
                        self.part("TileGrout", label + "_grout", line_pos, line_size, "grout", False)
                        coord += step
        else:
            for i in range(1, len(points)-1):
                self.triangle(group, label, points[0], points[i], points[i+1], mat, collide)

    def save(self, path):
        ET.indent(self.root)
        ET.ElementTree(self.root).write(path, encoding="utf-8", xml_declaration=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bsp", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "assets/generated")
    args = parser.parse_args()
    bsp = BSP(args.bsp)
    args.output.mkdir(parents=True, exist_ok=True)
    scene = Scene()
    obj = ["# GoldSrc geometry, replacement material colors; 1 unit = 1 Roblox stud", "mtllib fy_pool_day.mtl"]
    index = 1
    surfaces = list(bsp.surfaces())
    used = collections.Counter()
    for face_id, model_id, name, kind, points, uvs in surfaces:
        scene.surface(face_id, name, kind, points)
        mat = material(name, kind)
        used[mat] += 1
        obj.extend((f"o model_{model_id}_face_{face_id}", f"usemtl {mat}"))
        obj.extend("v " + " ".join(f"{v:.7g}" for v in p) for p in points)
        obj.extend(f"vt {u:.7g} {v:.7g}" for u, v in uvs)
        for i in range(1, len(points)-1):
            obj.append("f " + " ".join(f"{j}/{j}" for j in (index, index+i, index+i+1)))
        index += len(points)
    spawns = []
    for entity in bsp.entities:
        kind = entity.get("classname")
        if kind in {"info_player_start", "info_player_deathmatch"}:
            p = position(tuple(map(float, entity["origin"].split())))
            spawns.append(p)
            scene.part("Spawns", f"{'CT' if kind == 'info_player_start' else 'T'}_{len(spawns):02}",
                       sub(p, (0, 1.5, 0)), (2, 0.1, 2), "concrete", False, cls="SpawnLocation")
    scene.save(args.output / "fy_pool_day.rbxmx")
    (args.output / "fy_pool_day.obj").write_text("\n".join(obj) + "\n")
    mtl = []
    for name, (rgb, _) in MATERIALS.items():
        mtl.extend([f"newmtl {name}", "Kd " + " ".join(f"{c/255:.5f}" for c in rgb),
                    "d " + ("0.6" if name == "water" else "0.45" if name == "glass" else "1"), ""])
    (args.output / "fy_pool_day.mtl").write_text("\n".join(mtl))
    all_points = [p for surface in surfaces for p in surface[4]]
    report = {
        "source": args.bsp.name,
        "source_sha256": hashlib.sha256(bsp.data).hexdigest(),
        "scale": SCALE,
        "faces_in_bsp": len(bsp.faces),
        "exported_surfaces": len(surfaces),
        "parts": dict(scene.counts),
        "spawn_count": len(spawns),
        "materials": dict(used),
        "bounds": {"min": [min(p[i] for p in all_points) for i in range(3)],
                   "max": [max(p[i] for p in all_points) for i in range(3)]},
        "limitations": ["Static doors and buttons", "Visual water only; no swimming",
                         "No weapons, sounds, lightmaps or CS game logic", "Thin surface collision shells",
                         "Original texture pixels excluded; procedural replacement colors and tile grout",
                         "Source map geometry is not covered by replacement material permissions"],
    }
    (args.output / "import-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()

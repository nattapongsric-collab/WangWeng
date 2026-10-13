"""สร้างฉากหลัก scenes/main.tscn (บ้าน 2 ชั้น + สวนหลังบ้าน) แบบอัตโนมัติ
รัน: python3 tools/gen_level.py

ผังบ้าน (มองจากบน, หน่วยเมตร, หน้าบ้าน = +Z, สวน = -Z)
ชั้น 1 (y=0)                          ชั้น 2 (y=3.2)
 z=0  +-------+----+--------+          +------+------+-------+
      | ครัว  |ทาง | ห้องพระ |          | ห้อง  | ห้อง  | ห้อง  |
      | 0-7   |เดิน| 9-16    |          | ยาย  | เด็ก  | เก็บของ|
 z=5  +--D----+    +---------+          +--D---+--D---+---D---+
      | ห้องนั่งเล่น  | โถงบันได|          |   ทางเดินชั้นบน z5-8   |
      | 0-9         | 9-16   |          +---------+------------+
 z=12 +-----D(หน้า)-+--------+          |ห้องนั่ง  | ชานพัก/บันได|
                                         +---------+------------+
หมายเหตุ: ถ้าแก้ฉากใน Godot Editor แล้ว อย่ารันสคริปต์นี้ซ้ำ (จะเขียนทับ)
"""
import math
import os
import numpy as np

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "scenes", "main.tscn")


# =================================================================== tscn writer
class Scene:
    def __init__(self):
        self.ext = []  # (type, path, id)
        self.ext_ids = {}
        self.subs = []  # (type, id, body)
        self.sub_ids = {}
        self.nodes = []
        self.names = {}

    def ext_res(self, typ, path):
        if path in self.ext_ids:
            return self.ext_ids[path]
        rid = f"{len(self.ext) + 1}_r"
        self.ext.append((typ, path, rid))
        self.ext_ids[path] = rid
        return rid

    def sub_res(self, typ, body):
        key = (typ, body)
        if key in self.sub_ids:
            return self.sub_ids[key]
        rid = f"{typ}_{len(self.subs) + 1}"
        self.subs.append((typ, rid, body))
        self.sub_ids[key] = rid
        return rid

    def uniq(self, parent, name):
        k = (parent, name)
        if k not in self.names:
            self.names[k] = 0
            return name
        self.names[k] += 1
        return f"{name}{self.names[k] + 1}"

    def node(self, name, typ=None, parent=".", props=None, groups=None, instance=None):
        name = self.uniq(parent, name)
        self.nodes.append((name, typ, parent, props or {}, groups or [], instance))
        return name if parent == "." else f"{parent}/{name}"

    def write(self, path):
        lines = [f"[gd_scene load_steps={len(self.ext) + len(self.subs) + 1} format=3]", ""]
        for typ, p, rid in self.ext:
            lines.append(f'[ext_resource type="{typ}" path="{p}" id="{rid}"]')
        lines.append("")
        for typ, rid, body in self.subs:
            lines.append(f'[sub_resource type="{typ}" id="{rid}"]')
            if body:
                lines.append(body)
            lines.append("")
        for i, (name, typ, parent, props, groups, inst) in enumerate(self.nodes):
            head = f'[node name="{name}"'
            if typ:
                head += f' type="{typ}"'
            if i > 0:
                head += f' parent="{parent}"'
            if inst:
                head += f' instance=ExtResource("{inst}")'
            if groups:
                head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
            head += "]"
            lines.append(head)
            for k, v in props.items():
                lines.append(f"{k} = {v}")
            lines.append("")
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
        print("wrote", path, "nodes:", len(self.nodes), "subs:", len(self.subs))


S = Scene()


def f(x):
    return f"{x:.4f}".rstrip("0").rstrip(".") if abs(x) > 1e-9 else "0"


def v3(v):
    return f"Vector3({f(v[0])}, {f(v[1])}, {f(v[2])})"


def col(c, a=1.0):
    return f"Color({f(c[0])}, {f(c[1])}, {f(c[2])}, {f(a)})"


def rot_matrix(yaw=0.0, pitch=0.0, roll=0.0):
    """องศา: yaw รอบ Y, pitch รอบ X, roll รอบ Z  (ลำดับ Y * X * Z)"""
    y, p, r = map(math.radians, (yaw, pitch, roll))
    Ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    Rx = np.array([[1, 0, 0], [0, math.cos(p), -math.sin(p)], [0, math.sin(p), math.cos(p)]])
    Rz = np.array([[math.cos(r), -math.sin(r), 0], [math.sin(r), math.cos(r), 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


def xform(pos, yaw=0.0, pitch=0.0, roll=0.0, m=None):
    if m is None:
        m = rot_matrix(yaw, pitch, roll)
    vals = [m[i][j] for i in range(3) for j in range(3)] + list(pos)
    return "Transform3D(" + ", ".join(f(v) for v in vals) + ")"


def look_basis(direction):
    """basis ที่แกน -Z ชี้ไปทาง direction"""
    d = np.array(direction, float)
    d /= np.linalg.norm(d)
    z = -d
    up = np.array([0, 1, 0.0])
    x = np.cross(up, z)
    x /= np.linalg.norm(x)
    y = np.cross(z, x)
    return np.array([x, y, z]).T  # columns = axes


def mat(name):
    return f'ExtResource("{S.ext_res("Material", f"res://assets/materials/{name}.tres")}")'


def box_mesh(size):
    return f'SubResource("{S.sub_res("BoxMesh", f"size = {v3(size)}")}")'


def box_shape(size):
    return f'SubResource("{S.sub_res("BoxShape3D", f"size = {v3(size)}")}")'


def cyl_mesh(rt, rb, h, segs=16):
    return f'SubResource("{S.sub_res("CylinderMesh", f"top_radius = {f(rt)}\nbottom_radius = {f(rb)}\nheight = {f(h)}\nradial_segments = {segs}\nrings = 1")}")'


def sphere_mesh(r, hscale=1.0):
    return f'SubResource("{S.sub_res("SphereMesh", f"radius = {f(r)}\nheight = {f(r * 2 * hscale)}\nradial_segments = 14\nrings = 7")}")'


def prism_mesh(size):
    return f'SubResource("{S.sub_res("PrismMesh", f"size = {v3(size)}")}")'


GEO = "NavRegion/Geometry"
FURN = "NavRegion/Furniture"


def box(name, center, size, material, parent=GEO, collide=True, groups=None, yaw=0.0, pitch=0.0, roll=0.0, shadow=True, layer=1):
    t = xform(center, yaw, pitch, roll)
    if collide:
        n = S.node(name, "StaticBody3D", parent, {"transform": t, "collision_layer": str(layer), "collision_mask": "0"}, groups)
        mp = {"mesh": box_mesh(size), "surface_material_override/0": mat(material)}
        if not shadow:
            mp["cast_shadow"] = "0"
        S.node("Mesh", "MeshInstance3D", n, mp)
        S.node("Shape", "CollisionShape3D", n, {"shape": box_shape(size)})
        return n
    mp = {"transform": t, "mesh": box_mesh(size), "surface_material_override/0": mat(material)}
    if not shadow:
        mp["cast_shadow"] = "0"
    return S.node(name, "MeshInstance3D", parent, mp, groups)


def cyl(name, center, rt, rb, h, material, parent=GEO, collide_box=None, groups=None, yaw=0.0, pitch=0.0, roll=0.0, segs=16):
    t = xform(center, yaw, pitch, roll)
    if collide_box:
        n = S.node(name, "StaticBody3D", parent, {"transform": t, "collision_layer": "1", "collision_mask": "0"}, groups)
        S.node("Mesh", "MeshInstance3D", n, {"mesh": cyl_mesh(rt, rb, h, segs), "surface_material_override/0": mat(material)})
        S.node("Shape", "CollisionShape3D", n, {"shape": box_shape(collide_box)})
        return n
    return S.node(name, "MeshInstance3D", parent, {"transform": t, "mesh": cyl_mesh(rt, rb, h, segs), "surface_material_override/0": mat(material)}, groups)


def sphere(name, center, r, material, parent=GEO, hscale=1.0, groups=None):
    return S.node(name, "MeshInstance3D", parent, {"transform": xform(center), "mesh": sphere_mesh(r, hscale), "surface_material_override/0": mat(material)}, groups)


T = 0.2  # ความหนาผนัง


def wall(name, axis, fixed, a0, a1, y0, y1, openings, material, groups=None, parent=GEO, frames=True):
    """axis='x' ผนังวิ่งตามแกน x ที่ z=fixed, axis='z' วิ่งตามแกน z ที่ x=fixed
    openings = [(center, width, bottom, top), ...]"""
    segs = []
    cur = a0
    for (c, w, b, t) in sorted(openings):
        o0, o1 = c - w / 2, c + w / 2
        if o0 > cur + 1e-6:
            segs.append((cur, o0, y0, y1))
        if b > y0 + 1e-6:
            segs.append((o0, o1, y0, b))
        if t < y1 - 1e-6:
            segs.append((o0, o1, t, y1))
        cur = o1
    if cur < a1 - 1e-6:
        segs.append((cur, a1, y0, y1))
    for i, (s0, s1, b, t) in enumerate(segs):
        ln = s1 - s0
        h = t - b
        if axis == "x":
            c = ((s0 + s1) / 2, (b + t) / 2, fixed)
            size = (ln, h, T)
        else:
            c = (fixed, (b + t) / 2, (s0 + s1) / 2)
            size = (T, h, ln)
        box(f"{name}_{i}", c, size, material, parent, True, groups)
    if frames:
        for (c, w, b, t) in openings:
            is_window = b > y0 + 0.1
            fm = "wood_dark"
            for side in (-1, 1):
                p = c + side * (w / 2 - 0.04)
                if axis == "x":
                    box(f"{name}_frame", (p, (b + t) / 2, fixed), (0.08, t - b, T + 0.06), fm, parent, False, groups)
                else:
                    box(f"{name}_frame", (fixed, (b + t) / 2, p), (T + 0.06, t - b, 0.08), fm, parent, False, groups)
            if axis == "x":
                box(f"{name}_frame", (c, t - 0.04, fixed), (w, 0.08, T + 0.06), fm, parent, False, groups)
            else:
                box(f"{name}_frame", (fixed, t - 0.04, c), (T + 0.06, 0.08, w), fm, parent, False, groups)
            if is_window:
                # ลูกกรงไม้
                n = int(w / 0.17)
                for k in range(1, n):
                    p = c - w / 2 + k * w / n
                    if axis == "x":
                        box(f"{name}_bar", (p, (b + t) / 2, fixed), (0.035, t - b, 0.035), fm, parent, False, groups)
                    else:
                        box(f"{name}_bar", (fixed, (b + t) / 2, p), (0.035, t - b, 0.035), fm, parent, False, groups)
                if axis == "x":
                    box(f"{name}_sill", (c, b + 0.02, fixed), (w + 0.1, 0.04, T + 0.12), fm, parent, False, groups)
                else:
                    box(f"{name}_sill", (fixed, b + 0.02, c), (T + 0.12, 0.04, w + 0.1), fm, parent, False, groups)


def door_op(c, w=1.3, y0=0.0):
    return (c, w, y0, y0 + 2.3)


def win_op(c, w=1.4, y0=0.0):
    return (c, w, y0 + 0.9, y0 + 2.1)


# =================================================================== root
S.node("Main", "Node3D", props={"script": f'ExtResource("{S.ext_res("Script", "res://scripts/level/level.gd")}")'})

env = S.sub_res("Environment", "\n".join([
    "background_mode = 1",
    f"background_color = {col((0.012, 0.016, 0.03))}",
    "ambient_light_source = 2",
    f"ambient_light_color = {col((0.16, 0.18, 0.28))}",
    "ambient_light_energy = 0.45",
    "tonemap_mode = 2",
    "tonemap_exposure = 1.1",
    "glow_enabled = true",
    "glow_intensity = 0.6",
    "glow_bloom = 0.05",
    "fog_enabled = true",
    "fog_mode = 0",
    f"fog_light_color = {col((0.03, 0.035, 0.05))}",
    "fog_density = 0.035",
    "fog_sky_affect = 0.4",
    "adjustment_enabled = true",
    "adjustment_contrast = 1.08",
    "adjustment_saturation = 0.75",
]))
S.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": f'SubResource("{env}")'})

moon_dir = (0.35, -0.7, 0.62)  # แสงจันทร์ส่องจากด้านหลังบ้าน (สวน) เข้าหน้าต่าง
S.node("Moonlight", "DirectionalLight3D", ".", {
    "transform": xform((0, 20, 0), m=look_basis(moon_dir)),
    "light_color": col((0.5, 0.6, 1.0)),
    "light_energy": "1.1",
    "light_specular": "0.2",
    "shadow_enabled": "true",
    "shadow_bias": "0.04",
    "directional_shadow_mode": "0",
    "directional_shadow_max_distance": "45.0",
})
mp = -np.array(moon_dir) / np.linalg.norm(moon_dir) * 90 + np.array([8, 0, -6])
S.node("Moon", "MeshInstance3D", ".", {"transform": xform(tuple(mp)), "mesh": sphere_mesh(4.0), "surface_material_override/0": mat("moon"), "cast_shadow": "0"})

nav_mesh = S.sub_res("NavigationMesh", "\n".join([
    "geometry_parsed_geometry_type = 1",
    "geometry_collision_mask = 1",
    "geometry_source_geometry_mode = 0",
    "cell_size = 0.1",
    "cell_height = 0.1",
    "agent_height = 1.5",
    "agent_radius = 0.3",
    "agent_max_climb = 0.3",
    "agent_max_slope = 45.0",
    "region_min_size = 4.0",
    "edge_max_error = 1.0",
]))
S.node("NavRegion", "NavigationRegion3D", ".", {"navigation_mesh": f'SubResource("{nav_mesh}")'})
S.node("Geometry", "Node3D", "NavRegion")
S.node("Furniture", "Node3D", "NavRegion")
for grp in ("Doors", "Items", "Props", "Candles", "Triggers", "Markers", "PatrolPoints", "Writings", "Lights"):
    S.node(grp, "Node3D", ".")

PROPS = {k: S.ext_res("PackedScene", f"res://scenes/props/{k}.tscn") for k in
         ("door", "pickup", "candle", "hide_spot", "noisy_prop", "altar", "trigger_zone", "safe_zone")}


def inst(kind, name, parent, pos, yaw=0.0, props=None, groups=None):
    p = {"transform": xform(pos, yaw)}
    p.update(props or {})
    return S.node(name, None, parent, p, groups, instance=PROPS[kind])


def q(s):
    return '"' + s.replace('"', '\\"') + '"'


# =================================================================== พื้น/เพดาน
Y2 = 3.2  # พื้นชั้น 2
box("Floor_Kitchen", (3.5, -0.1, 2.5), (7.0, 0.2, 5.0), "tile")
box("Floor_HallShrine", (11.5, -0.1, 2.5), (9.0, 0.2, 5.0), "floor_wood")
box("Floor_Front", (8.0, -0.1, 8.5), (16.0, 0.2, 7.0), "floor_wood")
box("Ground_Garden", (8.0, -0.1, -7.5), (22.0, 0.2, 15.0), "grass")
box("Ground_Front", (8.0, -0.1, 17.0), (40.0, 0.2, 10.0), "grass", collide=False)
box("Ground_SideW", (-12.0, -0.1, -2.0), (20.0, 0.2, 30.0), "grass", collide=False)
box("Ground_SideE", (28.0, -0.1, -2.0), (20.0, 0.2, 30.0), "grass", collide=False)
box("Ground_Back", (8.0, -0.1, -24.0), (40.0, 0.2, 20.0), "grass", collide=False)

# พื้นชั้นสอง (เว้นช่องบันได x10-14.6, z10.2-12)
HOLE = (10.0, 14.6, 10.2, 12.0)
for nm, (x0, x1, z0, z1) in {
    "A": (0, 16, 0, 10.2), "B": (0, 10, 10.2, 12), "C": (14.6, 16, 10.2, 12)}.items():
    cx, cz, sx, sz = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
    box(f"Floor2_{nm}", (cx, 3.14, cz), (sx, 0.12, sz), "floor_wood")
    box(f"Ceil1_{nm}", (cx, 3.04, cz), (sx, 0.08, sz), "ceiling", collide=False)
box("Ceil2", (8.0, 6.07, 6.0), (16.4, 0.14, 12.4), "ceiling", collide=False)

# หลังคาทรงไทย (มองเห็นจากสวน)
rise, run = 3.6, 6.8
ang = math.degrees(math.atan2(rise, run))
ln = math.hypot(rise, run)
box("Roof_Back", (8.0, 6.15 + rise / 2, 6.0 - run / 2), (18.0, 0.16, ln), "roof", collide=False, pitch=-ang)
box("Roof_Front", (8.0, 6.15 + rise / 2, 6.0 + run / 2), (18.0, 0.16, ln), "roof", collide=False, pitch=ang)
for x in (0.0, 16.0):
    S.node("Gable", "MeshInstance3D", GEO, {"transform": xform((x, 6.15 + rise / 2, 6.0), yaw=90),
                                           "mesh": prism_mesh((12.0, rise, 0.2)), "surface_material_override/0": mat("wall_wood")})
box("Roof_Ridge", (8.0, 6.15 + rise + 0.05, 6.0), (18.2, 0.18, 0.3), "wood_dark", collide=False)

# =================================================================== ผนังชั้น 1 (0 → 3.0)
H1 = (0.0, 3.0)
wall("W1_Front", "x", 12.0, -0.1, 16.1, *H1, [door_op(4.5), win_op(1.8), win_op(7.3), win_op(12.5)], "wall_plaster")
wall("W1_Back", "x", 0.0, -0.1, 16.1, *H1, [door_op(8.0), win_op(3.5), win_op(12.5)], "wall_plaster")
wall("W1_West", "z", 0.0, 0.1, 11.9, *H1, [win_op(2.5), win_op(8.5)], "wall_plaster")
wall("W1_East", "z", 16.0, 0.1, 11.9, *H1, [win_op(8.5)], "wall_plaster")
wall("W1_KitchenLiving", "x", 5.0, 0.1, 7.1, *H1, [door_op(3.5)], "wall_plaster")
wall("W1_KitchenHall", "z", 7.0, 0.1, 4.9, *H1, [], "wall_plaster")
wall("W1_HallShrine", "z", 9.0, 0.1, 5.1, *H1, [door_op(2.5)], "wall_plaster")
wall("W1_ShrineStair", "x", 5.0, 9.1, 15.9, *H1, [], "wall_plaster")
wall("W1_LivingStair", "z", 9.0, 5.1, 11.9, *H1, [(7.9, 3.4, 0.0, 2.6)], "wall_plaster")

# =================================================================== ผนังชั้น 2 (3.2 → 6.0)
H2 = (Y2, 6.0)
wall("W2_Front", "x", 12.0, -0.1, 16.1, *H2, [win_op(1.8, 1.4, Y2), win_op(6.0, 1.4, Y2), win_op(12.5, 1.4, Y2)], "wall_wood")
wall("W2_Back", "x", 0.0, -0.1, 16.1, *H2, [win_op(3.0, 1.2, Y2), win_op(8.5, 1.2, Y2), win_op(13.5, 1.2, Y2)], "wall_wood")
wall("W2_West", "z", 0.0, 0.1, 11.9, *H2, [win_op(2.5, 1.2, Y2), win_op(10.0, 1.2, Y2)], "wall_wood")
wall("W2_East", "z", 16.0, 0.1, 11.9, *H2, [win_op(6.5, 1.2, Y2)], "wall_wood")
wall("W2_Rooms", "x", 5.0, 0.1, 15.9, *H2, [door_op(3.0, 1.3, Y2), door_op(8.0, 1.3, Y2), door_op(13.5, 1.3, Y2)], "wall_wood")
wall("W2_GmaKid", "z", 6.0, 0.1, 4.9, *H2, [], "wall_wood")
wall("W2_KidStore", "z", 11.0, 0.1, 4.9, *H2, [], "wall_wood")
wall("W2_HallSit", "x", 8.0, 0.1, 9.1, *H2, [(4.5, 1.4, Y2, Y2 + 2.4)], "wall_wood")
# ผนังห้องนั่งเล่นชั้นบน ↔ ชานพัก: เฟส <2 ทึบ / เฟส ≥2 มีช่องประตูโผล่ขึ้นมา
wall("W2_SitLanding", "z", 9.0, 8.1, 11.9, *H2, [], "wall_wood", groups=["phase_hide_2"])
wall("W2_SitLandingOpen", "z", 9.0, 8.1, 11.9, *H2, [(9.5, 1.3, Y2, Y2 + 2.3)], "wall_wood", groups=["phase_show_2"])
# ทางเดินถูกปิด (บ้านจำได้)
wall("W2_HallBlock", "z", 9.0, 5.1, 7.9, *H2, [], "wall_wood", groups=["phase_show_2"], frames=False)
# ราวกันตก ช่องบันได
box("Rail_Long", (12.3, Y2 + 0.5, 10.2), (4.6, 1.0, 0.08), "wood_dark", parent=GEO)
box("Rail_Short", (10.0, Y2 + 0.5, 11.1), (0.08, 1.0, 1.8), "wood_dark", parent=GEO)
for x in np.arange(10.2, 14.6, 0.5):
    box("Baluster", (x, Y2 + 0.5, 10.2), (0.05, 1.0, 0.05), "wood_dark", collide=False)

# =================================================================== บันได (ramp ชน + ขั้นบันไดเพื่อความสวยงาม)
x0, x1, zc, sw = 10.0, 14.6, 11.05, 1.7
rise = Y2
run = x1 - x0
ang = math.degrees(math.atan2(rise, run))
ln = math.hypot(rise, run) + 0.35
th = 0.12
# แก้บัค: ปลายบนของ ramp เคยโผล่เกินพื้นชั้น 2 ~0.1 ม. เป็นขอบกั้นตอนเดินลง -> ตัดปลายบนให้พอดีระดับพื้นชั้น 2
_a = math.radians(math.degrees(math.atan2(rise, run)))
_trim = 0.2095  # ความยาวที่ตัดออกจากปลายบน
ln -= _trim
# ramp: เอียงรอบแกน Z (roll) ให้ปลาย +x สูงขึ้น
cx, cy = (x0 + x1) / 2 + 0.05, rise / 2 - th / 2 * math.cos(math.radians(ang)) + 0.02
cx -= (_trim / 2) * math.cos(_a)  # ขยับศูนย์กลางลงตามแนวลาด เพราะตัดเฉพาะปลายบน
cy -= (_trim / 2) * math.sin(_a)
S_r = S.node("StairRamp", "StaticBody3D", GEO, {"transform": xform((cx, cy, zc), roll=ang), "collision_layer": "1", "collision_mask": "0"})
S.node("Shape", "CollisionShape3D", S_r, {"shape": box_shape((ln, th, sw))})
steps = 16
for i in range(steps):
    sx = x0 + (i + 0.5) * run / steps
    top = (i + 1) * rise / steps
    box("Step", (sx, top / 2, zc), (run / steps + 0.01, top, sw), "wood_dark", collide=False)
box("StairStringer", (12.3, 1.6, 11.95), (4.8, 3.2, 0.08), "wood_dark", collide=False)

# =================================================================== รั้วสวน
FH = 2.3
box("Fence_Back", (8.0, FH / 2, -14.0), (20.2, FH, 0.3), "brick")
box("Fence_W", (-2.0, FH / 2, -7.0), (0.3, FH, 14.0), "brick")
box("Fence_E", (18.0, FH / 2, -7.0), (0.3, FH, 14.0), "brick")
box("Fence_W2", (-1.0, FH / 2, 0.0), (2.0, FH, 0.3), "brick")
box("Fence_E2", (17.0, FH / 2, 0.0), (2.0, FH, 0.3), "brick")
for x in (-2.0, 18.0, 4.0, 12.0):
    box("FencePost", (x, FH / 2 + 0.1, -14.0), (0.45, FH + 0.2, 0.45), "brick", collide=False)

# =================================================================== เฟอร์นิเจอร์ helpers
def table(name, center, size, top_mat="wood_dark", parent=FURN, groups=None):
    cx, h, cz = center[0], size[1], center[2]
    y0 = center[1]
    n = box(name, (cx, y0 + h - 0.025, cz), (size[0], 0.05, size[2]), top_mat, parent, False, groups)
    for sxs in (-1, 1):
        for szs in (-1, 1):
            box(name + "_leg", (cx + sxs * (size[0] / 2 - 0.06), y0 + (h - 0.05) / 2, cz + szs * (size[2] / 2 - 0.06)),
                (0.06, h - 0.05, 0.06), top_mat, parent, False, groups)
    # collision เป็นกล่องเต็ม (ผีและผู้เล่นมุดใต้โต๊ะไม่ได้)
    sb = S.node(name + "_Col", "StaticBody3D", parent, {"transform": xform((cx, y0 + h / 2, cz)), "collision_layer": "1", "collision_mask": "0"}, groups)
    S.node("Shape", "CollisionShape3D", sb, {"shape": box_shape((size[0], h, size[2]))})
    return y0 + h


def chair(name, pos, yaw, groups=None, parent=FURN):
    """เก้าอี้ไม้ หันหน้าไปทาง yaw (ด้านหน้าของเก้าอี้ = -Z local)"""
    sb = S.node(name, "StaticBody3D", parent, {"transform": xform(pos, yaw), "collision_layer": "1", "collision_mask": "0"}, groups)
    S.node("Shape", "CollisionShape3D", sb, {"transform": xform((0, 0.45, 0)), "shape": box_shape((0.46, 0.9, 0.46))})
    for xx in (-0.19, 0.19):
        for zz in (-0.19, 0.19):
            S.node("Leg", "MeshInstance3D", sb, {"transform": xform((xx, 0.225, zz)), "mesh": box_mesh((0.04, 0.45, 0.04)), "surface_material_override/0": mat("wood_dark")})
    S.node("Seat", "MeshInstance3D", sb, {"transform": xform((0, 0.47, 0)), "mesh": box_mesh((0.44, 0.04, 0.44)), "surface_material_override/0": mat("wood_dark")})
    S.node("Back", "MeshInstance3D", sb, {"transform": xform((0, 0.72, 0.2)), "mesh": box_mesh((0.44, 0.48, 0.04)), "surface_material_override/0": mat("wood_dark")})


def rocking_chair(name, pos, yaw, groups=None, parent=FURN):
    sb = S.node(name, "StaticBody3D", parent, {"transform": xform(pos, yaw), "collision_layer": "1", "collision_mask": "0"}, groups)
    S.node("Shape", "CollisionShape3D", sb, {"transform": xform((0, 0.5, 0.05)), "shape": box_shape((0.6, 1.0, 0.85))})
    for xx in (-0.27, 0.27):
        S.node("Rocker", "MeshInstance3D", sb, {"transform": xform((xx, 0.05, 0.05)), "mesh": box_mesh((0.04, 0.06, 0.95)), "surface_material_override/0": mat("wood_dark")})
        S.node("Arm", "MeshInstance3D", sb, {"transform": xform((xx, 0.62, -0.02)), "mesh": box_mesh((0.05, 0.05, 0.6)), "surface_material_override/0": mat("wood_dark")})
        S.node("Post", "MeshInstance3D", sb, {"transform": xform((xx, 0.3, -0.2)), "mesh": box_mesh((0.04, 0.5, 0.04)), "surface_material_override/0": mat("wood_dark")})
    S.node("Seat", "MeshInstance3D", sb, {"transform": xform((0, 0.42, 0.02)), "mesh": box_mesh((0.56, 0.05, 0.55)), "surface_material_override/0": mat("fabric")})
    S.node("Back", "MeshInstance3D", sb, {"transform": xform((0, 0.85, 0.3), pitch=-14), "mesh": box_mesh((0.56, 0.85, 0.05)), "surface_material_override/0": mat("wood_dark")})


def frame_photo(name, pos, yaw, size=(0.5, 0.65), groups=None):
    box(name, pos, (size[0] + 0.08, size[1] + 0.08, 0.03), "wood_dark", parent=FURN, collide=False, yaw=yaw, groups=groups)
    m = rot_matrix(yaw)
    fwd = m @ np.array([0, 0, 0.018])
    box(name + "_pic", tuple(np.array(pos) + fwd), (size[0], size[1], 0.005), "photo", parent=FURN, collide=False, yaw=yaw, groups=groups)


def writing(text, pos, yaw, size=96, groups=None, color=(0.5, 0.02, 0.02)):
    S.node("Writing", "Label3D", "Writings", {
        "transform": xform(pos, yaw),
        "pixel_size": "0.006",
        "shaded": "true",
        "double_sided": "false",
        "modulate": col(color, 0.92),
        "outline_size": "0",
        "text": q(text),
        "font": f'ExtResource("{S.ext_res("FontFile", "res://assets/fonts/Charmonman-Bold.ttf")}")',
        "font_size": str(size),
    }, groups)


def pickup(pid, pos, item="", amount=1, note="", visual="key", yaw=0.0):
    props = {"pickup_id": q(pid), "visual": q(visual)}
    if item:
        props["item_id"] = q(item)
    if amount != 1:
        props["amount"] = str(amount)
    if note:
        props["note_id"] = q(note)
    inst("pickup", "Pickup_" + pid, "Items", pos, yaw, props)


def candle(cid, pos, lit=False, shrine=False, radius=3.8):
    props = {"candle_id": q(cid), "lit": "true" if lit else "false"}
    if shrine:
        props["shrine"] = "true"
    if radius != 3.8:
        props["radius"] = f(radius)
    inst("candle", "Candle_" + cid, "Candles", pos, 0, props)


def prop(kind, pos, yaw=0.0):
    inst("noisy_prop", "Prop_" + kind, "Props", pos, yaw, {"kind": q(kind)})


def hide(kind, pos, yaw):
    inst("hide_spot", "Hide_" + kind, FURN, pos, yaw, {"kind": q(kind)})


def door(did, hinge, yaw, width=1.3, locked=False, key="", text="", exit_=False):
    props = {"door_id": q(did), "width": f(width)}
    if locked:
        props["locked"] = "true"
    if key:
        props["key_id"] = q(key)
    if text:
        props["locked_text"] = q(text)
    if exit_:
        props["is_exit"] = "true"
    inst("door", "Door_" + did, "Doors", hinge, yaw, props)


def trigger(zid, center_floor, size, min_phase=0, max_phase=9):
    inst("trigger_zone", "Trigger_" + zid, "Triggers", center_floor, 0,
         {"zone_id": q(zid), "size": v3(size), "min_phase": str(min_phase), "max_phase": str(max_phase)})


# =================================================================== ประตู
door("front", (3.85, 0, 12.0), 0, locked=True, text="ประตูหน้าล็อกตาย... ไม่ว่าจะดึงแค่ไหนก็ไม่เปิด", exit_=True)
door("door_kitchen", (2.85, 0, 5.0), 0)
door("back", (7.35, 0, 0.0), 0, locked=True, key="key_backdoor", text="ประตูหลังบ้านล็อกอยู่ — ต้องใช้กุญแจ")
door("shrine", (9.0, 0, 1.85), -90)
door("grandma", (2.35, Y2, 5.0), 0, locked=True, key="key_grandma", text="ห้องของยาย... ล็อกอยู่ กุญแจอยู่ที่ไหนกันนะ")
door("kid", (7.35, Y2, 5.0), 0)
door("storage", (12.85, Y2, 5.0), 0, locked=True, key="key_storage", text="ห้องเก็บของล็อกอยู่ — ต้องใช้กุญแจห้องเก็บของ")

# =================================================================== ห้องนั่งเล่น
L = FURN
box("Sofa_Base", (0.6, 0.22, 8.2), (0.8, 0.44, 2.4), "fabric", L)
box("Sofa_Back", (0.22, 0.62, 8.2), (0.18, 0.8, 2.4), "fabric", L)
box("Sofa_ArmA", (0.6, 0.45, 6.92), (0.8, 0.3, 0.16), "fabric", L)
box("Sofa_ArmB", (0.6, 0.45, 9.48), (0.8, 0.3, 0.16), "fabric", L)
top = table("CoffeeTable", (2.5, 0, 8.2), (0.9, 0.45, 1.4))
box("Rug", (2.8, 0.005, 8.2), (2.6, 0.01, 3.2), "fabric", L, collide=False)
box("Cabinet_Living", (5.5, 0.45, 5.38), (2.2, 0.9, 0.5), "wood_dark", L)
frame_photo("Portrait_Living", (5.5, 1.9, 5.11), 0)
frame_photo("Portrait_Living2", (4.6, 1.75, 5.11), 0, (0.3, 0.4))
box("ShoeRack", (6.4, 0.25, 11.65), (1.2, 0.5, 0.35), "wood_dark", L)
hide("wardrobe", (0.43, 0, 11.0), 90)
rocking_chair("RockingChair_Before", (1.9, 0, 10.4), 160, groups=["phase_hide_1"])
rocking_chair("RockingChair_Hall", (7.65, 0, 2.6), 180, groups=["phase_show_1"])
pickup("letter_grandma", (2.65, top, 8.55), note="letter_grandma", visual="letter")
prop("bottle", (2.75, top, 7.65))
prop("chair", (3.8, 0, 9.4), 200)
prop("jar", (8.4, 0, 11.5))
candle("living", (5.0, 0.9, 5.4), lit=True)
writing("กลับมาแล้ว", (2.2, 1.7, 5.115), 0, groups=["phase_show_1"])
writing("ใช้หนี้", (8.8, 1.5, 9.5), -90, size=120, groups=["phase_show_3"])

# =================================================================== ครัว
box("Counter", (2.6, 0.45, 0.42), (5.0, 0.9, 0.6), "wood_dark", L)
box("CounterTop", (2.6, 0.92, 0.42), (5.04, 0.04, 0.64), "plaster_white", L, collide=False)
box("UpperCab", (1.3, 2.2, 0.3), (2.2, 0.7, 0.4), "wood_dark", L, collide=False)
box("Fridge", (6.45, 0.85, 0.5), (0.75, 1.7, 0.7), "metal_white", L)
ktop = table("DiningTable", (3.5, 0, 2.7), (1.6, 0.76, 1.0))
for nm, pos, yaw in (("ChairW", (2.4, 0, 2.7), -90), ("ChairE", (4.6, 0, 2.7), 90), ("ChairN", (3.5, 0, 1.75), 180), ("ChairS", (3.5, 0, 3.65), 0)):
    # หน้าเก้าอี้ = -Z local → yaw ให้หันเข้าหาโต๊ะ
    chair(nm, pos, yaw, groups=["phase_hide_1"])
for nm, pos, yaw in (("ChairW2", (0.5, 0, 2.0), -90), ("ChairW3", (0.5, 0, 3.4), -90), ("ChairN2", (5.4, 0, 1.2), 180), ("ChairS2", (1.4, 0, 4.55), 0)):
    # เฟส 1: เก้าอี้ทุกตัวหันหน้าเข้ากำแพง
    chair(nm, pos, yaw + 180, groups=["phase_show_1"])
cyl("WaterJar", (6.45, 0.4, 4.35), 0.28, 0.32, 0.8, "clay", L, collide_box=(0.6, 0.8, 0.6))
hide("wardrobe", (6.59, 0, 2.6), -90)
pickup("key_backdoor", (4.6, 0.94, 0.5), "key_backdoor", visual="key", yaw=20)
pickup("note_kitchen", (3.1, ktop, 2.55), note="note_kitchen", visual="letter", yaw=-10)
pickup("matches_kitchen", (3.95, ktop, 2.95), "matches", 3, visual="matches")
candle("kitchen", (3.55, ktop, 2.85))
prop("pot", (1.4, 0.94, 0.45))
prop("pot", (2.2, 0.94, 0.5))
prop("bottle", (0.8, 0.94, 0.4))
prop("bucket", (5.6, 0, 4.4))
prop("jar", (0.45, 0, 4.4))

# =================================================================== ทางเดิน + ห้องพระ
box("ShoeCab_Hall", (8.72, 0.4, 4.1), (0.35, 0.8, 0.8), "wood_dark", L)
inst("altar", "Altar", FURN, (15.35, 0, 2.5), -90)
candle("shrine_l", (15.25, 0.7, 1.9), lit=True, shrine=True, radius=3.0)
candle("shrine_r", (15.25, 0.7, 3.1), lit=True, shrine=True, radius=3.0)
box("ShrineMat", (13.6, 0.005, 2.5), (1.6, 0.01, 2.4), "red_lacquer", L, collide=False)
ltop = table("LowTable_Shrine", (13.4, 0, 2.5), (0.5, 0.35, 0.8), "red_lacquer")
pickup("note_shrine", (13.4, ltop, 2.5), note="note_shrine", visual="letter", yaw=90)
box("Cab_Shrine", (10.0, 0.5, 0.45), (1.4, 1.0, 0.5), "wood_dark", L)
pickup("key_storage", (10.2, 1.0, 0.45), "key_storage", visual="key", yaw=-30)
frame_photo("Portrait_Shrine1", (11.0, 1.9, 0.115), 0)
frame_photo("Portrait_Shrine2", (12.0, 1.9, 0.115), 0)
inst("safe_zone", "SafeZone_Shrine", ".", (12.5, 0, 2.5), 0, {"size": v3((6.7, 3.0, 4.7))})

# =================================================================== โถงบันได
box("Clock", (15.65, 1.0, 6.0), (0.45, 2.0, 0.5), "wood_dark", L)
sphere("ClockFace", (15.41, 1.55, 6.0), 0.14, "plaster_white", L, 0.15)
stop = table("SideTable_Stair", (15.55, 0, 7.9), (0.55, 0.8, 0.8))
candle("stairhall", (15.55, stop, 7.9))
box("Boxes_UnderStair1", (14.6, 0.35, 11.4), (0.8, 0.7, 0.8), "wood_dark", L)
box("Boxes_UnderStair2", (15.4, 0.3, 11.3), (0.6, 0.6, 0.7), "wood_dark", L)
hide("wardrobe", (12.0, 0, 5.41), 0)
prop("bottle", (12.6, 0, 8.6))
prop("bucket", (10.8, 0, 6.2))

# =================================================================== ห้องยาย (ชั้น 2)
hide("bed", (0.85, Y2, 2.1), 0)
hide("wardrobe", (5.59, Y2, 3.6), -90)
box("Dresser", (3.5, Y2 + 0.4, 0.4), (1.2, 0.8, 0.5), "wood_dark", L)
box("Mirror", (3.5, Y2 + 1.45, 0.14), (0.6, 0.9, 0.03), "mirror", L, collide=False)
box("Chest", (1.0, Y2 + 0.25, 4.35), (0.9, 0.5, 0.5), "wood_dark", L)
box("ChestLid", (1.0, Y2 + 0.52, 4.35), (0.94, 0.06, 0.54), "gold", L, collide=False)
pickup("letter_final", (1.0, Y2 + 0.58, 2.5), note="letter_final", visual="letter", yaw=15)
pickup("contract", (1.0, Y2 + 0.55, 4.35), "contract", visual="contract")
pickup("matches_grandma", (3.85, Y2 + 0.8, 0.45), "matches", 2, visual="matches")
candle("grandma", (3.15, Y2 + 0.8, 0.45))
frame_photo("Portrait_Gma", (5.885, Y2 + 1.7, 1.5), -90)
writing("ยายรอหลานอยู่", (3.0, Y2 + 1.8, 0.115), 0, size=80, groups=["phase_show_2"])

# =================================================================== ห้องเด็ก (ชั้น 2)
hide("kid_bed", (6.65, Y2, 1.25), 0)
hide("wardrobe", (10.59, Y2, 2.6), -90)
dtop = table("Desk_Kid", (8.6, Y2, 0.42), (1.2, 0.76, 0.55))
pickup("drawing_kid", (8.3, dtop, 0.45), note="drawing_kid", visual="drawing")
pickup("photo_2", (8.95, dtop, 0.4), "photo_piece", visual="photo")
candle("kid", (9.1, dtop, 0.6))
box("Shelf_Kid", (6.6, Y2 + 0.5, 4.72), (0.8, 1.0, 0.35), "wood_dark", L)
pickup("matches_kid", (6.6, Y2 + 1.0, 4.72), "matches", 2, visual="matches")
sphere("Toy1", (9.6, Y2 + 0.12, 3.9), 0.12, "toy_red", L)
sphere("Toy2", (9.9, Y2 + 0.08, 4.2), 0.08, "toy_blue", L)
sphere("DollHead", (6.6, Y2 + 0.7, 0.6), 0.07, "doll", L)
box("DollBody", (6.6, Y2 + 0.6, 0.66), (0.12, 0.16, 0.08), "cloth_white", L, collide=False)
prop("bottle", (9.4, Y2, 3.4))
writing("พี่รออยู่", (8.5, Y2 + 1.7, 0.115), 0, size=70, groups=["phase_show_1"], color=(0.35, 0.05, 0.05))

# =================================================================== ห้องเก็บของ (ชั้น 2)
for i, (c, s) in enumerate([((12.0, Y2 + 0.4, 0.6), (0.8, 0.8, 0.8)), ((12.9, Y2 + 0.4, 0.55), (0.7, 0.8, 0.7)),
                            ((12.1, Y2 + 1.05, 0.6), (0.6, 0.5, 0.6)), ((15.3, Y2 + 0.4, 1.0), (0.9, 0.8, 0.9)),
                            ((15.4, Y2 + 0.35, 4.3), (0.8, 0.7, 0.8)),
                            ((15.35, Y2 + 1.05, 1.05), (0.6, 0.5, 0.6))]):
    box(f"Crate{i}", c, s, "wood_dark", L)
box("Shelf_Storage", (15.65, Y2 + 1.0, 2.7), (0.45, 2.0, 1.4), "wood_dark", L)
box("OldMattress", (14.05, Y2 + 1.0, 0.28), (1.3, 2.0, 0.2), "cloth_white", L, pitch=8)
hide("wardrobe", (11.41, Y2, 3.3), 90)
stt = table("Table_Storage", (13.6, Y2, 2.2), (1.0, 0.8, 0.7))
pickup("photo_3", (13.75, stt, 2.2), "photo_piece", visual="photo")
pickup("newspaper", (13.3, stt, 2.3), note="newspaper", visual="newspaper")
candle("storage", (13.95, stt, 1.95))
for pos in ((12.5, Y2, 3.0), (13.1, Y2, 3.8), (14.5, Y2, 3.2)):
    prop("bottle", pos)
prop("jar", (14.6, Y2, 1.9))
prop("bucket", (12.2, Y2, 2.0))

# =================================================================== ทางเดิน/ห้องนั่งเล่นชั้นบน/ชานพัก
htop = table("Console_Hall2", (6.0, Y2, 7.68), (1.2, 0.8, 0.4))
candle("hall2", (6.2, htop, 7.68))
frame_photo("Portrait_Hall2a", (2.0, Y2 + 1.7, 7.885), 180)
frame_photo("Portrait_Hall2b", (12.5, Y2 + 1.7, 7.885 + 0.0), 180)
box("Bench_Sit", (0.55, Y2 + 0.25, 10.0), (0.8, 0.5, 2.0), "wood_dark", L)
sttop = table("Table_Sit", (2.6, Y2, 10.0), (0.8, 0.45, 1.2))
candle("sitting", (2.6, sttop, 10.0), lit=True)
hide("wardrobe", (8.59, Y2, 11.2), -90)
rocking_chair("RockingChair_Sit", (5.5, Y2, 10.0), -70, groups=["phase_show_2"])
writing("อย่าหนี", (8.88, Y2 + 1.6, 6.5), -90, size=110, groups=["phase_show_2"])
writing("กลับมา", (9.12, Y2 + 1.6, 6.5), 90, size=110, groups=["phase_show_2"])
writing("ใช้หนี้", (14.0, Y2 + 1.8, 5.12), 0, size=110, groups=["phase_show_3"])

# =================================================================== สวนหลังบ้าน
G = FURN
cyl("TreeTrunk", (2.5, 2.0, -9.0), 0.28, 0.42, 4.0, "trunk", G, collide_box=(0.7, 4.0, 0.7))
for (dx, dy, dz, r) in ((0, 4.6, 0, 2.0), (1.2, 4.0, 0.6, 1.5), (-1.0, 4.2, -0.5, 1.6), (0.4, 5.6, -0.3, 1.4), (-0.6, 3.8, 1.0, 1.2)):
    sphere("Leaves", (2.5 + dx, dy, -9.0 + dz), r, "leaves", G, 0.8)
box("Branch", (3.6, 3.1, -9.0), (2.2, 0.14, 0.14), "trunk", G, collide=False, roll=12)
box("HangingCloth", (4.3, 2.35, -9.0), (0.5, 1.4, 0.02), "cloth_white", G, collide=False, yaw=30)
# ศาลพระภูมิ
box("Spirit_Pillar", (13.0, 0.7, -11.0), (0.25, 1.4, 0.25), "plaster_white", G)
box("Spirit_Platform", (13.0, 1.43, -11.0), (0.9, 0.06, 0.9), "plaster_white", G)
box("Spirit_House", (13.0, 1.72, -11.15), (0.55, 0.5, 0.45), "red_lacquer", G, collide=False)
S.node("Spirit_Roof", "MeshInstance3D", G, {"transform": xform((13.0, 2.12, -11.15), yaw=90),
                                           "mesh": prism_mesh((0.6, 0.35, 0.7)), "surface_material_override/0": mat("gold")})
box("Spirit_Door", (13.0, 1.7, -10.92), (0.18, 0.3, 0.02), "gold", G, collide=False)
for dx in (-0.3, 0.3):
    sphere("Garland", (13.0 + dx, 1.52, -10.62), 0.06, "plaster_white", G)
candle("spirit", (12.72, 1.46, -10.7), lit=True)
pickup("photo_1", (13.2, 1.46, -10.68), "photo_piece", visual="photo")
# บ่อน้ำ
cyl("Well", (5.0, 0.4, -4.5), 0.75, 0.8, 0.8, "brick", G, collide_box=(1.5, 0.8, 1.5), segs=20)
cyl("WellWater", (5.0, 0.79, -4.5), 0.62, 0.62, 0.02, "water", G)
for dx in (-0.8, 0.8):
    box("WellPost", (5.0 + dx, 1.2, -4.5), (0.1, 2.4, 0.1), "wood_dark", G, collide=False)
box("WellBeam", (5.0, 2.35, -4.5), (1.8, 0.1, 0.1), "wood_dark", G, collide=False)
box("WellRope", (5.0, 1.75, -4.5), (0.02, 1.1, 0.02), "plaster_white", G, collide=False)
# ราวตากผ้า
for z in (-3.0, -7.0):
    box("LinePost", (0.6, 1.0, z), (0.08, 2.0, 0.08), "wood_dark", G)
box("Line", (0.6, 1.95, -5.0), (0.015, 0.015, 4.0), "black", G, collide=False)
for z in (-3.8, -5.0, -6.2):
    box("HangCloth", (0.6, 1.45, z), (0.02, 1.0, 0.7), "cloth_white", G, collide=False)
# โอ่งน้ำ
cyl("Jar1", (10.6, 0.45, -0.75), 0.32, 0.36, 0.9, "clay", G, collide_box=(0.7, 0.9, 0.7))
cyl("Jar2", (11.4, 0.45, -0.8), 0.32, 0.36, 0.9, "clay", G, collide_box=(0.7, 0.9, 0.7))
# พุ่มไม้
for (x, z, r) in ((-1.0, -12.5, 0.9), (16.8, -12.8, 1.0), (17.0, -3.0, 0.8), (-1.2, -1.5, 0.7), (8.0, -13.2, 0.8), (16.9, -7.5, 0.9)):
    sphere("Bush", (x, r * 0.5, z), r, "leaves", G, 0.7)
# ทางเดินดิน
for i, (x, z) in enumerate(((8.0, -0.9), (8.6, -2.2), (9.5, -3.6), (10.4, -5.0), (11.3, -6.6), (12.1, -8.2), (12.7, -9.6))):
    box("Path", (x, 0.005, z), (1.0, 0.01, 1.2), "dirt", G, collide=False, yaw=-30)
prop("bucket", (6.1, 0, -3.5))
prop("jar", (9.0, 0, -6.2))

# =================================================================== ทริกเกอร์
trigger("stairs_glimpse", (10.2, 0, 11.05), (1.0, 2.5, 1.6), 0, 0)
trigger("garden", (8.0, 0, -1.6), (2.4, 2.5, 1.6))
trigger("shrine", (10.5, 0, 2.5), (1.6, 2.5, 3.0))
trigger("upstairs", (15.3, Y2, 11.1), (1.3, 2.5, 1.7))
trigger("kid_room", (8.0, Y2, 4.0), (1.4, 2.5, 1.2))
trigger("hall_after", (10.5, Y2, 6.5), (2.0, 2.5, 2.8), 2)

# =================================================================== จุดลาดตระเวนของผี + จุดเกิด
patrol = [(3.0, 0, 8.5), (6.5, 0, 10.3), (2.0, 0, 3.6), (5.5, 0, 3.6), (8.0, 0, 1.2), (12.0, 0, 7.5), (14.8, 0, 6.5),
          (5.5, 0, -6.0), (11.5, 0, -6.5), (3.0, 0, -11.5), (9.0, 0, -11.5),
          (3.2, Y2, 2.8), (8.5, Y2, 2.8), (13.5, Y2, 3.3), (4.0, Y2, 6.5), (12.5, Y2, 6.5), (4.5, Y2, 10.3), (15.3, Y2, 9.0)]
for p in patrol:
    S.node("Patrol", "Marker3D", "PatrolPoints", {"transform": xform(p)}, ["ghost_patrol"])
S.node("GhostSpawn1", "Marker3D", "Markers", {"transform": xform((6.4, 0, -4.0))})
S.node("GhostSpawn2", "Marker3D", "Markers", {"transform": xform((3.0, Y2, 10.5))})
S.node("GhostSpawn3", "Marker3D", "Markers", {"transform": xform((13.5, Y2, 3.3))})

# =================================================================== ตัวละคร / ระบบ
S.node("Player", None, ".", {"transform": xform((4.5, 0.05, 10.6), 0)}, instance=S.ext_res("PackedScene", "res://scenes/player.tscn"))
S.node("Ghost", None, ".", {"transform": xform((6.4, 0, -4.0))}, instance=S.ext_res("PackedScene", "res://scenes/ghost.tscn"))
S.node("Hallucinations", "Node3D", ".", {"script": f'ExtResource("{S.ext_res("Script", "res://scripts/enemy/hallucinations.gd")}")'})
S.node("AmbientEvents", "Node", ".", {"script": f'ExtResource("{S.ext_res("Script", "res://scripts/level/ambient_events.gd")}")'})
S.node("HUD", None, ".", {}, instance=S.ext_res("PackedScene", "res://scenes/hud.tscn"))
S.node("AmbHouse", "AudioStreamPlayer", ".", {"stream": f'ExtResource("{S.ext_res("AudioStream", "res://assets/audio/amb_house.wav")}")',
                                              "volume_db": "-6.0", "autoplay": "true", "bus": '&"Ambience"'})
S.node("AmbNight", "AudioStreamPlayer", ".", {"stream": f'ExtResource("{S.ext_res("AudioStream", "res://assets/audio/amb_night.wav")}")',
                                              "volume_db": "-24.0", "autoplay": "true", "bus": '&"Ambience"'})

S.write(OUT)

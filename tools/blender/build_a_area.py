# A 维修站：地面道路、远景（高架、残楼、塔）、雨水罐，以及整区摆放预览和导出。
# 摆放按 data/earth_*.csv 的格子坐标（目前每格 2 米，A 区 60×60 米）。
# 坐标换算：Godot 的 x = Blender 的 x；Godot 的 z = Blender 的 -y。
import math, random
import bpy, bmesh
from mathutils import Vector
import tyt_lib as L

CELL = 2.0


def G(gx, gz, z=0.0):
    """Godot 平面坐标（米）→ Blender 坐标。"""
    return (gx, -gz, z)


def viaduct_segment():
    """高架一段（拆件图 05）：一根桥墩 + 12 米桥面 + 两侧护栏。只当远景，不能上去。"""
    root = L.begin_asset("a_viaduct_seg")
    h, span, w = 9.0, 12.0, 7.0
    L.box("pier", (1.6, 2.4, h - 1.0), (0, 0, 0), "m_concrete", base=True)
    L.box("pier_cap", (2.2, w - 1.0, 1.0), (0, 0, h - 1.6), "m_concrete_trim", base=True)
    L.box("deck", (span, w, 0.8), (0, 0, h - 0.6), "m_concrete", base=True)
    for sy in (-1, 1):
        L.box("curb", (span, 0.35, 0.5), (0, sy * (w / 2 - 0.175), h + 0.2), "m_concrete_trim", base=True)
        L.railing(f"rail_{sy}", [(-span / 2, sy * (w / 2 - 0.15), h + 0.7), (span / 2, sy * (w / 2 - 0.15), h + 0.7)],
                  h=0.8, post_gap=2.0, r=0.04)
    return root


def bg_ruin(kind):
    """远景残楼 3 种：方块楼身 + 黑窗洞 + 残缺楼顶。"""
    rnd = random.Random(kind)
    sizes = {1: (14, 12, 24), 2: (10, 10, 36), 3: (18, 10, 16)}
    w, d, h = sizes[kind]
    root = L.begin_asset(f"bg_ruin_{kind}")
    body = L.box("body", (w, d, h), (0, 0, 0), "m_concrete", base=True)
    # 楼顶塌一角
    L.cut(body, L.cutter_box((w * 0.6, d * 1.2, h * 0.5), (w * 0.45, 0, h), rot=(0, 0.5, 0)))
    wins = []
    floors = int(h / 3.2)
    for f in range(1, floors):
        z = f * 3.2 + 0.8
        for side, (ax, n_) in {"-Y": ("x", w), "+X": ("y", d)}.items():
            n = int(n_ / 2.6)
            for i in range(n):
                t = -n_ / 2 + (i + 0.5) * n_ / n
                if rnd.random() < 0.12:
                    continue
                if side == "-Y":
                    p = Vector((t, -d / 2 - 0.02, z))
                    sz = (1.3, 0.06, 1.6)
                else:
                    p = Vector((w / 2 + 0.02, t, z))
                    sz = (0.06, 1.3, 1.6)
                # 只留在楼身范围内（塌掉的那角不放窗）
                if p.x > w * 0.1 and z > h * 0.72:
                    continue
                wins.append(L.box("win", sz, p, "m_interior_dark", base=True))
    L.join(wins, "windows")
    # 楼顶几根露出来的柱子
    for i in range(3):
        x = -w / 2 + 1 + i * 2.2
        L.box("stub", (0.5, 0.5, rnd.uniform(1, 3)), (x, -d / 2 + 0.5, h), "m_concrete_dark", base=True)
    return root


def tower():
    """右上角的塔（地标）：混凝土塔身 + 钢架 + 顶上平台和天线。"""
    root = L.begin_asset("bg_tower")
    L.cyl("shaft", 2.2, 34, (0, 0, 0), "m_concrete", seg=16, r2=1.6)
    L.cyl("deck", 5.0, 2.5, (0, 0, 34), "m_concrete_trim", seg=20)
    L.cyl("deck_glass", 4.6, 2.0, (0, 0, 36.5), "m_glass", seg=20)
    L.cyl("roof", 5.2, 0.5, (0, 0, 38.5), "m_metal_dark", seg=20)
    L.cyl("mast", 0.25, 10, (0, 0, 39), "m_metal_paint", seg=8, r2=0.08)
    lat = []
    for a in range(4):
        ang = a * math.pi / 2 + math.pi / 4
        p0 = Vector((math.cos(ang) * 4.5, math.sin(ang) * 4.5, 0))
        p1 = Vector((math.cos(ang) * 2.0, math.sin(ang) * 2.0, 30))
        lat.append(L.beam("leg", p0, p1, 0.35, m="m_metal_rust"))
        for k in range(1, 6):
            q = p0.lerp(p1, k / 6)
            ang2 = ang + math.pi / 2
            q2 = Vector((math.cos(ang2), math.sin(ang2), 0)) * q.xy.length
            q2.z = q.z
            lat.append(L.beam("brace", q, q2, 0.18, m="m_metal_rust"))
    L.join(lat, "lattice")
    return root


def rain_tank():
    root = L.begin_asset("a_rain_tank")
    L.box("pad", (3.6, 3.6, 0.2), (0, 0, 0), "m_concrete_dark", base=True)
    L.cyl("tank", 1.5, 3.0, (0, 0, 0.2), "m_metal_paint", seg=24)
    L.cyl("lid", 1.55, 0.15, (0, 0, 3.2), "m_metal_dark", seg=24, r2=1.2)
    for z in (0.9, 2.1):
        L.cyl("ring", 1.53, 0.12, (0, 0, z), "m_metal_rust", seg=24)
    L.beam("inlet", (0, 0, 3.4), (0, -1.8, 3.4), 0.18, m="m_metal_paint", round_=True)
    L.beam("tap", (0, -1.5, 0.6), (0, -1.9, 0.6), 0.12, m="m_metal_dark", round_=True)
    lad = [L.beam("l", (1.52, -0.25, 0.2), (1.52, -0.25, 3.3), 0.05, m="m_yellow_paint", round_=True),
           L.beam("l", (1.52, 0.25, 0.2), (1.52, 0.25, 3.3), 0.05, m="m_yellow_paint", round_=True)]
    for k in range(1, 10):
        z = 0.2 + k * 0.32
        lad.append(L.beam("r", (1.52, -0.25, z), (1.52, 0.25, z), 0.035, m="m_yellow_paint", round_=True))
    L.join(lad, "ladder")
    return root


def ground_a():
    """A 区地面：污染土底 + 前广场地砖 + 东西向道路 + 通往广场和大门的支路。"""
    root = L.begin_asset("a_ground")
    L.box("dirt", (80, 90, 0.2), (30, -15, -0.2), "m_ground_polluted", base=True)
    L.box("plaza", (32, 18, 0.06), (26, -15, 0), "m_floor", base=True)
    # 广场分格缝
    seams = []
    for i in range(1, 8):
        x = 10 + i * 4
        seams.append(L.box("s", (0.06, 18, 0.01), (x, -15, 0.06), "m_concrete_dark", base=True))
    for j in range(1, 5):
        seams.append(L.box("s", (32, 0.06, 0.01), (26, -6 - j * 3.6, 0.06), "m_concrete_dark", base=True))
    L.join(seams, "plaza_seams")
    roads = []
    roads.append(L.box("road_ew", (80, 6, 0.05), (30, -37, 0), "m_asphalt", base=True))
    roads.append(L.box("road_s", (6, 10, 0.05), (26, -29, 0), "m_asphalt", base=True))
    roads.append(L.box("road_n", (8, 18, 0.05), (30, -49, 0), "m_asphalt", base=True))
    L.join(roads, "roads")
    curbs = []
    for y in (-34, -40):
        for (xa, xb) in ((-10, 23 if y == -34 else 26), (29 if y == -34 else 34, 70)):
            curbs.append(L.box("c", (xb - xa, 0.25, 0.15), ((xa + xb) / 2, y, 0), "m_concrete_trim", base=True))
    L.join(curbs, "curbs")
    marks = []
    for k in range(16):
        x = -8 + k * 5
        if 22 < x < 35:
            continue
        marks.append(L.box("dash", (2.5, 0.15, 0.01), (x, -37, 0.05), "m_road_line", base=True))
    for k in range(6):
        marks.append(L.box("zebra", (0.5, 4.0, 0.01), (23.8 + k * 0.9, -37, 0.05), "m_road_line", base=True))
    L.join(marks, "road_marks")
    return root


def build_all():
    roots = {}
    for fn in (viaduct_segment, tower, rain_tank, ground_a):
        r = fn()
        roots[r.name] = r
    for k in (1, 2, 3):
        r = bg_ruin(k)
        roots[r.name] = r
    return roots

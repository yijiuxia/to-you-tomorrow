# 各区通用小道具 kit_*（《美术拆件_A维修站》3.2 + 拆件图/a_repair_parts.png 08）
# 比例按 ARK-01 默认高 1.2 米。每个道具一个模型，坏 / 修好主要换贴图；遮棚、路灯有 ruin / repaired 两种零件。
import math, random
import bmesh, bpy
from mathutils import Vector
import tyt_lib as L


def crate(name, sx, sy, sz):
    root = L.begin_asset(name)
    L.box("body", (sx - 0.08, sy - 0.08, sz - 0.08), (0, 0, 0.04), "m_crate", base=True)
    e = 0.09
    parts = []
    # 12 条边框（黄边）
    for z in (e / 2, sz - e / 2):
        for y in (-sy / 2 + e / 2, sy / 2 - e / 2):
            parts.append(L.box("e", (sx, e, e), (0, y, z), "m_yellow_paint"))
        for x in (-sx / 2 + e / 2, sx / 2 - e / 2):
            parts.append(L.box("e", (e, sy, e), (x, 0, z), "m_yellow_paint"))
    for x in (-sx / 2 + e / 2, sx / 2 - e / 2):
        for y in (-sy / 2 + e / 2, sy / 2 - e / 2):
            parts.append(L.box("e", (e, e, sz), (x, y, sz / 2), "m_yellow_paint"))
    L.join(parts, "frame")
    # 侧面加强筋
    ribs = []
    n = max(2, int(sx / 0.5))
    for i in range(1, n):
        x = -sx / 2 + sx * i / n
        for sgn in (-1, 1):
            ribs.append(L.box("r", (0.05, 0.03, sz - 2 * e), (x, sgn * (sy / 2 - 0.02), sz / 2), "m_metal_paint"))
    L.join(ribs, "ribs")
    # 正面铭牌位置（贴纸用）
    L.box("label", (min(0.5, sx * 0.4), 0.01, 0.25), (sx * 0.2, -sy / 2 - 0.005, sz * 0.55), "m_white_paint")
    return root


def cabinet():
    root = L.begin_asset("kit_power_cabinet")
    L.box("plinth", (1.1, 0.6, 0.12), (0, 0, 0), "m_concrete_dark", base=True)
    L.box("body", (1.0, 0.5, 1.75), (0, 0, 0.12), "m_metal_paint", base=True)
    for x in (-0.24, 0.24):
        L.box("door", (0.44, 0.03, 1.5), (x, -0.26, 0.25), "m_metal_paint", base=True)
        L.box("handle", (0.03, 0.04, 0.18), (x + (0.17 if x < 0 else -0.17), -0.29, 1.0), "m_metal_dark", base=True)
    L.box("roof", (1.2, 0.72, 0.06), (0, -0.06, 1.87), "m_metal_dark", base=True)
    L.box("warn", (0.18, 0.01, 0.16), (-0.24, -0.28, 1.45), "m_yellow_paint", base=True)
    for x in (-0.3, 0.3):
        L.box("vent", (0.3, 0.01, 0.12), (x, 0.255, 1.5), "m_metal_dark", base=True)
    return root


def bollard():
    root = L.begin_asset("kit_bollard")
    L.cyl("post", 0.12, 0.9, (0, 0, 0), "m_yellow_paint", seg=12)
    for z in (0.45, 0.72):
        L.cyl("band", 0.125, 0.1, (0, 0, z), "m_hazard_black", seg=12)
    L.cyl("cap", 0.12, 0.04, (0, 0, 0.9), "m_hazard_black", seg=12, r2=0.09)
    return root


def cone():
    root = L.begin_asset("kit_traffic_cone")
    L.box("base", (0.42, 0.42, 0.05), (0, 0, 0), "m_hazard_black", base=True)
    L.cyl("cone", 0.16, 0.65, (0, 0, 0.05), "m_orange_paint", seg=16, r2=0.03)
    L.cyl("stripe", 0.115, 0.12, (0, 0, 0.3), "m_white_paint", seg=16, r2=0.09)
    return root


def railing_seg(name, corner=False):
    root = L.begin_asset(name)
    pts = [(-1, 0, 0), (1, 0, 0)] if not corner else [(-1, 0, 0), (0, 0, 0), (0, 1, 0)]
    pts = [Vector(p) for p in pts]
    parts = []
    for p in pts:
        parts.append(L.box("post", (0.12, 0.12, 1.0), p, "m_yellow_paint", base=True))
        parts.append(L.box("band", (0.125, 0.125, 0.12), p + Vector((0, 0, 0.7)), "m_hazard_black", base=True))
        parts.append(L.box("foot", (0.24, 0.24, 0.04), p, "m_metal_dark", base=True))
    L.join(parts, "posts")
    rails = []
    for i in range(len(pts) - 1):
        for z in (0.9, 0.5):
            rails.append(L.beam("rail", pts[i] + Vector((0, 0, z)), pts[i + 1] + Vector((0, 0, z)), 0.07, m="m_yellow_paint", round_=True))
    L.join(rails, "rails")
    return root


def pipe_stack():
    root = L.begin_asset("kit_pipe_stack")
    r = 0.22
    L_ = 4.0
    parts = []
    rows = [4, 3, 2, 1]
    for j, n in enumerate(rows):
        z = r + j * r * math.sqrt(3)
        for i in range(n):
            x = (i - (n - 1) / 2) * 2 * r
            parts.append(L.cyl("pipe", r, L_, (-L_ / 2, x, z), "m_metal_rust", axis="X", seg=14))
            parts.append(L.cyl("hole", r * 0.78, L_ + 0.02, (-L_ / 2 - 0.01, x, z), "m_interior_dark", axis="X", seg=14))
    L.join(parts, "pipes")
    st = []
    for x in (-1.2, 1.2):
        st.append(L.box("strap", (0.06, 4 * 2 * r + 0.06, 0.06), (x, 0, 2 * r * 0.2), "m_yellow_paint"))
        h = r + 3 * r * math.sqrt(3) + r
        for sgn in (-1, 1):
            st.append(L.beam("strap", (x, sgn * (4 * r + 0.02), 0.05), (x, sgn * 0.25, h), 0.06, m="m_yellow_paint"))
    L.join(st, "straps")
    for x in (-1.2, 1.2):
        L.box("chock", (0.2, 2.0, 0.12), (x, 0, 0), "m_wood", base=True)
    return root


def _cloth(name, w, d, z, sag, m, tear=0.0, seed=1, state=None):
    bm = bmesh.new()
    nx, ny = 12, 10
    vs = {}
    for i in range(nx + 1):
        for j in range(ny + 1):
            u, v = i / nx - 0.5, j / ny - 0.5
            h = z - sag * (1 - (2 * u) ** 2) * (1 - (2 * v) ** 2)
            vs[i, j] = bm.verts.new((u * w, v * d, h))
    rnd = random.Random(seed)
    for i in range(nx):
        for j in range(ny):
            if tear and 1 < i < nx - 2 and rnd.random() < tear:
                continue
            bm.faces.new((vs[i, j], vs[i + 1, j], vs[i + 1, j + 1], vs[i, j + 1]))
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.02)
    return L._obj_from_bm(name, bm, m, (0, 0, 0), (0, 0, 0), None, state)


def canopy():
    root = L.begin_asset("kit_canopy")
    w, d, h = 4.0, 3.0, 2.6
    posts = []
    for x in (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            posts.append(L.cyl("post", 0.05, h, (x, y, 0), "m_metal_rust", seg=8))
            posts.append(L.box("foot", (0.25, 0.25, 0.05), (x, y, 0), "m_concrete_dark", base=True))
    for y in (-d / 2, d / 2):
        posts.append(L.beam("tie", (-w / 2, y, h), (w / 2, y, h), 0.06, m="m_metal_rust", round_=True))
    L.join(posts, "frame")
    _cloth("cloth_clean", w + 0.2, d + 0.2, h + 0.02, 0.35, "m_canvas_red", state="repaired")
    _cloth("cloth_torn", w + 0.2, d + 0.2, h + 0.02, 0.45, "m_canvas_red", tear=0.3, seed=7, state="ruin")
    # 破布垂下来的布条
    rnd = random.Random(5)
    strips = []
    for k in range(6):
        x = rnd.uniform(-w / 2, w / 2)
        y = rnd.choice((-d / 2 - 0.1, d / 2 + 0.1))
        strips.append(L.box("strip", (0.25, 0.01, rnd.uniform(0.4, 0.9)), (x, y, h - 0.9), "m_canvas_red", base=True))
    L.join(strips, "cloth_strips").__setitem__("state", "ruin")
    return root


def hanging_crate():
    root = L.begin_asset("kit_hanging_crate")
    s = 1.2
    b = L.box("body", (s, s * 0.8, s * 0.8), (0, 0, 0), "m_crate", base=True)
    bev = b.modifiers.new("bevel", "BEVEL")
    bev.width = 0.08
    bev.segments = 2
    with bpy.context.temp_override(object=b, active_object=b):
        bpy.ops.object.modifier_apply(modifier=bev.name)
    L.box_uv(b)
    parts = []
    for x in (-s / 2 + 0.05, s / 2 - 0.05):
        parts.append(L.box("band", (0.08, s * 0.82, s * 0.82), (x, 0, -0.01), "m_yellow_paint", base=True))
    L.join(parts, "bands")
    ring = L.cyl("ring", 0.14, 0.05, (0, 0, s * 0.8 + 0.12), "m_metal_dark", axis="Y", seg=12, base=False)
    L.box("lug", (0.08, 0.08, 0.14), (0, 0, s * 0.8), "m_metal_dark", base=True)
    return root


def street_lamp():
    root = L.begin_asset("kit_street_lamp")
    L.cyl("base", 0.22, 0.4, (0, 0, 0), "m_concrete_dark", seg=12)
    L.cyl("pole", 0.08, 5.0, (0, 0, 0.4), "m_metal_paint", seg=10, r2=0.06)
    L.beam("arm", (0, 0, 5.2), (0, -1.0, 5.35), 0.07, m="m_metal_paint", round_=True)
    L.box("head", (0.35, 0.7, 0.14), (0, -1.15, 5.3), "m_metal_paint", base=True)
    L.box("lamp_on", (0.28, 0.6, 0.03), (0, -1.15, 5.28), "m_light_warm", base=True, state="repaired")
    L.box("lamp_off", (0.28, 0.6, 0.03), (0, -1.15, 5.28), "m_glass", base=True, state="ruin")
    L.box("box", (0.18, 0.12, 0.35), (0, -0.1, 1.2), "m_metal_dark", base=True)
    return root


def flag():
    root = L.begin_asset("kit_flag")
    L.cyl("base", 0.18, 0.15, (0, 0, 0), "m_concrete_dark", seg=10)
    L.cyl("pole", 0.04, 4.0, (0, 0, 0.15), "m_metal_paint", seg=8)
    bm = bmesh.new()
    nx, nz = 8, 4
    vs = {}
    for i in range(nx + 1):
        for j in range(nz + 1):
            x = 0.05 + 1.2 * i / nx
            vs[i, j] = bm.verts.new((x, 0.08 * math.sin(i / nx * math.pi * 2) * (i / nx), 3.2 + 0.8 * j / nz))
    for i in range(nx):
        for j in range(nz):
            bm.faces.new((vs[i, j], vs[i + 1, j], vs[i + 1, j + 1], vs[i, j + 1]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.01)
    L._obj_from_bm("cloth", bm, "m_blue_panel", (0, 0, 0), (0, 0, 0), None, None)
    return root


def shelf_parts(loc=(0, 0, 0), rot_z=0.0, prefix="shelf"):
    """仓库金属货架：长 2 米、深 0.6 米、高 2 米，4 层。最底层板离地 0.12 米、层间净高 0.45 米，
    放得下旧种子罐（高 0.3 米）。"""
    from mathutils import Matrix
    R = Matrix.Rotation(rot_z, 3, "Z")
    o = Vector(loc)
    P = lambda x, y, z: o + R @ Vector((x, y, z))
    parts = []
    Lx, Dy, H = 2.0, 0.6, 2.0
    for x in (-Lx / 2 + 0.03, Lx / 2 - 0.03):
        for y in (-Dy / 2 + 0.03, Dy / 2 - 0.03):
            parts.append(L.box(prefix + "_post", (0.05, 0.05, H), P(x, y, 0), "m_metal_paint", base=True, rot=(0, 0, rot_z)))
    for z in (0.12, 0.62, 1.12, 1.62):
        parts.append(L.box(prefix + "_board", (Lx, Dy, 0.03), P(0, 0, z), "m_metal_dark", base=True, rot=(0, 0, rot_z)))
        parts.append(L.box(prefix + "_lip", (Lx, 0.03, 0.06), P(0, -Dy / 2, z), "m_yellow_paint", base=True, rot=(0, 0, rot_z)))
    # 背后斜拉条
    parts.append(L.beam(prefix + "_x", P(-Lx / 2, Dy / 2, 0.1), P(Lx / 2, Dy / 2, H - 0.1), 0.03, m="m_metal_paint"))
    parts.append(L.beam(prefix + "_x", P(Lx / 2, Dy / 2, 0.1), P(-Lx / 2, Dy / 2, H - 0.1), 0.03, m="m_metal_paint"))
    return L.join(parts, prefix)


def shelf():
    root = L.begin_asset("kit_shelf")
    shelf_parts()
    # 架子上放几个杂物箱，最底层留空给种子罐
    for (x, z, s) in ((-0.55, 0.65, 0.4), (0.1, 0.65, 0.35), (0.6, 1.15, 0.45), (-0.4, 1.65, 0.3)):
        L.box("bin", (s, 0.45, s * 0.8), (x, 0, z), "m_crate", base=True)
    return root


def seed_can():
    """旧种子罐：落满灰的小金属罐，标签看不清（标签以后用贴纸）。高 0.3 米、直径 0.22 米，
    ARK-01（1.2 米）用手能拿起来的大小。"""
    root = L.begin_asset("kit_seed_can")
    L.cyl("body", 0.11, 0.26, (0, 0, 0), "m_metal_rust", seg=20)
    L.cyl("rim_b", 0.115, 0.02, (0, 0, 0), "m_metal_dark", seg=20)
    L.cyl("lid", 0.115, 0.04, (0, 0, 0.26), "m_metal_dark", seg=20)
    L.cyl("knob", 0.03, 0.02, (0, 0, 0.30), "m_metal_dark", seg=10)
    L.cyl("label", 0.112, 0.11, (0, 0, 0.08), "m_concrete_trim", seg=20)
    return root


KIT = {
    "kit_shelf": shelf,
    "kit_seed_can": seed_can,
    "kit_crate_l": lambda: crate("kit_crate_l", 2.0, 1.3, 1.3),
    "kit_crate_m": lambda: crate("kit_crate_m", 1.2, 1.0, 1.0),
    "kit_crate_s": lambda: crate("kit_crate_s", 0.75, 0.75, 0.7),
    "kit_power_cabinet": cabinet,
    "kit_railing": lambda: railing_seg("kit_railing"),
    "kit_railing_corner": lambda: railing_seg("kit_railing_corner", True),
    "kit_bollard": bollard,
    "kit_traffic_cone": cone,
    "kit_pipe_stack": pipe_stack,
    "kit_canopy": canopy,
    "kit_hanging_crate": hanging_crate,
    "kit_street_lamp": street_lamp,
    "kit_flag": flag,
}


def build_all():
    roots = {}
    x = 0
    for name, fn in KIT.items():
        r = fn()
        roots[name] = r
    return roots

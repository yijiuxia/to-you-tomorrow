# 《致明日的你》场景程序化建模的通用工具
# 用法：在 Blender 4.5 里 import tyt_lib as L，然后调用 L.box(...) 等函数搭模型。
# 约定：1 个单位 = 1 米，Z 朝上，-Y 是建筑正面（Godot 导入后正面朝 +Z）。
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

ROOT = r"E:\GODOT\to-you-tomorrow"
MODELS = os.path.join(ROOT, "assets", "models")
SOURCE = os.path.join(ROOT, "art_source", "blender")

# ---------------------------------------------------------------- 材质
# 名字和《美术拆件_A维修站》第 4 节的材料贴图一一对应，以后在 Godot 里换贴图按名字找。
PALETTE = {
    # 名字: (颜色RGB, 粗糙度, 金属度, 发光强度, 透明度)
    "m_concrete":        ((0.60, 0.58, 0.55), 0.85, 0.0, 0, 1),
    "m_concrete_dark":   ((0.40, 0.39, 0.37), 0.9, 0.0, 0, 1),
    "m_concrete_trim":   ((0.70, 0.69, 0.66), 0.8, 0.0, 0, 1),
    "m_metal_rust":      ((0.32, 0.18, 0.10), 0.8, 0.6, 0, 1),
    "m_metal_paint":     ((0.55, 0.56, 0.56), 0.55, 0.4, 0, 1),
    "m_metal_dark":      ((0.15, 0.16, 0.17), 0.6, 0.6, 0, 1),
    "m_corrugated":      ((0.13, 0.16, 0.20), 0.6, 0.3, 0, 1),
    "m_yellow_paint":    ((0.85, 0.58, 0.05), 0.5, 0.3, 0, 1),
    "m_hazard_black":    ((0.04, 0.04, 0.04), 0.6, 0.2, 0, 1),
    "m_orange_paint":    ((0.90, 0.32, 0.05), 0.5, 0.1, 0, 1),
    "m_white_paint":     ((0.85, 0.85, 0.82), 0.5, 0.1, 0, 1),
    "m_crate":           ((0.62, 0.62, 0.58), 0.6, 0.4, 0, 1),
    "m_canvas_red":      ((0.55, 0.22, 0.17), 0.9, 0.0, 0, 1),
    "m_tarp_grey":       ((0.32, 0.33, 0.33), 0.9, 0.0, 0, 1),
    "m_glass":           ((0.18, 0.26, 0.32), 0.15, 0.3, 0, 1),
    "m_glass_clear":     ((0.70, 0.85, 0.90), 0.05, 0.0, 0, 0.25),
    "m_interior_dark":   ((0.05, 0.05, 0.06), 0.9, 0.0, 0, 1),
    "m_interior_wall":   ((0.24, 0.27, 0.29), 0.7, 0.4, 0, 1),
    "m_floor":           ((0.50, 0.49, 0.46), 0.9, 0.0, 0, 1),
    "m_asphalt":         ((0.16, 0.16, 0.17), 0.95, 0.0, 0, 1),
    "m_road_line":       ((0.85, 0.85, 0.80), 0.8, 0.0, 0, 1),
    "m_ground_polluted": ((0.33, 0.29, 0.24), 1.0, 0.0, 0, 1),
    "m_rock":            ((0.42, 0.40, 0.37), 0.95, 0.0, 0, 1),
    "m_rubber":          ((0.05, 0.05, 0.05), 0.9, 0.0, 0, 1),
    "m_wood":            ((0.35, 0.24, 0.15), 0.9, 0.0, 0, 1),
    "m_soil":            ((0.22, 0.16, 0.11), 1.0, 0.0, 0, 1),
    "m_plant_dead":      ((0.36, 0.30, 0.20), 1.0, 0.0, 0, 1),
    "m_plant_green":     ((0.22, 0.42, 0.14), 0.9, 0.0, 0, 1),
    "m_red_paint":       ((0.55, 0.10, 0.08), 0.6, 0.2, 0, 1),
    "m_blue_panel":      ((0.12, 0.30, 0.55), 0.5, 0.2, 0, 1),
    "m_screen_off":      ((0.03, 0.05, 0.06), 0.2, 0.0, 0, 1),
    "m_light_warm":      ((1.00, 0.70, 0.30), 0.5, 0.0, 4, 1),
    "m_light_cyan":      ((0.20, 0.85, 1.00), 0.5, 0.0, 4, 1),
    "m_hologram":        ((0.20, 0.85, 1.00), 0.3, 0.0, 2, 0.35),
    "m_placeholder":     ((1.00, 0.00, 1.00), 0.9, 0.0, 0, 0.5),
}


def mat(name):
    """按名字取材质，没有就按调色板新建（Principled BSDF，按类型找节点，不按名字）。"""
    m = bpy.data.materials.get(name)
    if m:
        return m
    col, rough, metal, emit, alpha = PALETTE.get(name, ((0.5, 0.5, 0.5), 0.8, 0, 0, 1))
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*col, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*col, 1)
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    m.diffuse_color = (*col, alpha)
    return m


# ---------------------------------------------------------------- 场景和分组
def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.lights, bpy.data.cameras):
        for b in list(coll):
            if b.users == 0:
                coll.remove(b)


_cur_coll = None
_cur_root = None


def begin_asset(name):
    """开始一个资产：新建同名集合和同名空物体（根节点），之后创建的物体都挂在它下面。"""
    global _cur_coll, _cur_root
    coll = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    root = bpy.data.objects.new(name, None)
    root.empty_display_size = 1
    coll.objects.link(root)
    _cur_coll, _cur_root = coll, root
    return root


def _link(obj, parent=None, state=None):
    (_cur_coll or bpy.context.scene.collection).objects.link(obj)
    p = parent or _cur_root
    if p is not None:
        obj.parent = p
    if state:
        obj["state"] = state   # "ruin" / "repaired" 等，导出变体时按它筛选
    return obj


def _obj_from_bm(name, bm, m, loc, rot, parent, state, uv_scale=0.5):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    obj.location = loc
    obj.rotation_euler = rot
    if m:
        me.materials.append(mat(m) if isinstance(m, str) else m)
    _link(obj, parent, state)
    box_uv(obj, uv_scale)
    for p in me.polygons:
        p.use_smooth = False
    return obj


# ---------------------------------------------------------------- 基本形状
def box(name, size, loc=(0, 0, 0), m="m_concrete", rot=(0, 0, 0), parent=None, state=None, base=False):
    """长方体。size=(x,y,z)。base=True 时 loc 是底面中心（方便放在地上）。"""
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    if base:
        bmesh.ops.translate(bm, vec=(0, 0, sz / 2), verts=bm.verts)
    return _obj_from_bm(name, bm, m, loc, rot, parent, state)


def cyl(name, r, h, loc=(0, 0, 0), m="m_metal_paint", axis="Z", seg=16, r2=None, parent=None, state=None, base=True, rot=None):
    """圆柱（r2 给了就是圆台/圆锥）。axis 为 X/Y/Z。base=True 时从 loc 开始沿轴正方向长 h。"""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
    if base:
        bmesh.ops.translate(bm, vec=(0, 0, h / 2), verts=bm.verts)
    rr = {"Z": (0, 0, 0), "X": (0, math.pi / 2, 0), "Y": (-math.pi / 2, 0, 0)}[axis] if rot is None else rot
    return _obj_from_bm(name, bm, m, loc, rr, parent, state)


def sphere(name, r, loc=(0, 0, 0), m="m_metal_paint", seg=16, parent=None, state=None, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=r)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return _obj_from_bm(name, bm, m, loc, (0, 0, 0), parent, state)


def prism(name, pts, depth, loc=(0, 0, 0), m="m_concrete", plane="XZ", parent=None, state=None, rot=(0, 0, 0)):
    """把一个二维轮廓挤出成厚板。plane="XZ"：轮廓在 XZ 平面，沿 +Y 挤出 depth；
    plane="XY"：轮廓在地面，沿 +Z 挤出。"""
    bm = bmesh.new()
    vs = []
    for (a, b) in pts:
        co = (a, 0, b) if plane == "XZ" else ((0, a, b) if plane == "YZ" else (a, b, 0))
        vs.append(bm.verts.new(co))
    f = bm.faces.new(vs)
    ext = {"XZ": (0, depth, 0), "YZ": (depth, 0, 0), "XY": (0, 0, depth)}[plane]
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    nv = [g for g in r["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=ext, verts=nv)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj_from_bm(name, bm, m, loc, rot, parent, state)


def beam(name, p1, p2, w=0.1, h=None, m="m_metal_rust", parent=None, state=None, round_=False, seg=8):
    """两点之间的方钢 / 圆管。"""
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    L = d.length
    h = h or w
    bm = bmesh.new()
    if round_:
        bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=w / 2, radius2=w / 2, depth=L)
    else:
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(w, h, L), verts=bm.verts)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=q.to_matrix())
    return _obj_from_bm(name, bm, m, (p1 + p2) / 2, (0, 0, 0), parent, state)


def polyline_tube(name, pts, r=0.04, m="m_yellow_paint", parent=None, state=None, seg=6):
    """沿折线连续的一串圆管，合成一个物体（栏杆扶手、管子）。"""
    objs = [beam(f"{name}_{i}", pts[i], pts[i + 1], w=r * 2, m=m, round_=True, seg=seg, parent=parent, state=state)
            for i in range(len(pts) - 1)]
    return join(objs, name)


def railing(name, pts, h=1.1, post_gap=1.5, r=0.035, m="m_yellow_paint", parent=None, state=None, closed=False):
    """栏杆：沿折线放立柱 + 上下两道扶手。"""
    pts = [Vector(p) for p in pts]
    if closed:
        pts = pts + [pts[0]]
    parts = []
    top = [p + Vector((0, 0, h)) for p in pts]
    mid = [p + Vector((0, 0, h * 0.5)) for p in pts]
    parts.append(polyline_tube(name + "_top", top, r, m, parent, state))
    parts.append(polyline_tube(name + "_mid", mid, r * 0.8, m, parent, state))
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        n = max(1, int((b - a).length / post_gap))
        for k in range(n + (1 if i == len(pts) - 2 and not closed else 0)):
            p = a.lerp(b, k / n)
            parts.append(beam(f"{name}_post", p, p + Vector((0, 0, h)), w=r * 2.2, m=m, round_=True, seg=6, parent=parent, state=state))
    return join(parts, name)


def join(objs, name=None):
    """把几个物体合成一个（减少 Godot 里的节点数）。第一个物体保留。"""
    objs = [o for o in objs if o]
    if len(objs) <= 1:
        if objs and name:
            objs[0].name = name
        return objs[0] if objs else None
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs, selected_objects=objs):
        bpy.ops.object.join()
    if name:
        objs[0].name = name
        objs[0].data.name = name
    return objs[0]


def cut(obj, cutter, apply=True):
    """布尔挖洞：obj 减去 cutter，然后删掉 cutter。"""
    mod = obj.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    if apply:
        with bpy.context.temp_override(object=obj, active_object=obj):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
        box_uv(obj)
    return obj


def cutter_box(size, loc, rot=(0, 0, 0)):
    o = box("_cutter", size, loc, None, rot=rot)
    o.parent = None
    return o


# ---------------------------------------------------------------- 贴图坐标
def box_uv(obj, scale=0.5):
    """按面的朝向做“盒子投影”贴图坐标：1 米 = scale 个贴图格。所有物件用同一密度，
    这样一张无缝材料图贴到哪都一样大。"""
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    s = obj.scale
    for p in me.polygons:
        n = p.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            x, y, z = co.x * s.x, co.y * s.y, co.z * s.z
            if ax == 0:
                u, v = (y if n.x > 0 else -y), z
            elif ax == 1:
                u, v = (-x if n.y > 0 else x), z
            else:
                u, v = x, (y if n.z > 0 else -y)
            uv[li].uv = (u * scale, v * scale)


# ---------------------------------------------------------------- 常用组件
def arch_profile(half_w, spring, rise, n=24):
    """弓形拱顶轮廓（不是半圆）：从左起拱点到右起拱点，返回 (x, z) 列表。"""
    R = (half_w ** 2 + rise ** 2) / (2 * rise)
    cz = spring + rise - R
    a0 = math.asin(half_w / R)
    pts = []
    for i in range(n + 1):
        a = -a0 + 2 * a0 * i / n
        pts.append((R * math.sin(a), cz + R * math.cos(a)))
    return pts


def arch_height(x, half_w, spring, rise):
    R = (half_w ** 2 + rise ** 2) / (2 * rise)
    cz = spring + rise - R
    return cz + math.sqrt(max(0.0, R * R - x * x))


def window(name, w, h, loc, facing="-Y", depth=0.25, frame=0.08, mullions=(3, 2), m_frame="m_metal_paint",
           m_glass="m_glass", parent=None, state=None, broken=False):
    """窗：外框 + 竖横窗棂 + 玻璃。loc 是窗洞底边中心，窗贴在墙面上（墙洞要另外挖）。"""
    parts = []
    rotz = {"-Y": 0, "+Y": math.pi, "+X": math.pi / 2, "-X": -math.pi / 2}[facing]
    R = Matrix.Rotation(rotz, 3, "Z")
    base = Vector(loc)

    def P(x, y, z):
        return base + R @ Vector((x, y, z))
    # 外框
    parts.append(box(name + "_f", (w + frame * 2, frame, frame), P(0, 0, h + frame / 2), m_frame, rot=(0, 0, rotz), parent=parent, state=state))
    parts.append(box(name + "_f", (w + frame * 2, frame, frame), P(0, 0, -frame / 2), m_frame, rot=(0, 0, rotz), parent=parent, state=state))
    for sx in (-1, 1):
        parts.append(box(name + "_f", (frame, frame, h), P(sx * (w / 2 + frame / 2), 0, h / 2), m_frame, rot=(0, 0, rotz), parent=parent, state=state))
    cols, rows = mullions
    for i in range(1, cols):
        x = -w / 2 + w * i / cols
        parts.append(box(name + "_m", (frame * 0.5, frame * 0.6, h), P(x, 0, h / 2), m_frame, rot=(0, 0, rotz), parent=parent, state=state))
    for j in range(1, rows):
        z = h * j / rows
        parts.append(box(name + "_m", (w, frame * 0.6, frame * 0.5), P(0, 0, z), m_frame, rot=(0, 0, rotz), parent=parent, state=state))
    fr = join(parts, name + "_frame")
    g = box(name + "_glass", (w, 0.02, h), P(0, depth * 0.3, h / 2), m_glass, rot=(0, 0, rotz), parent=parent, state=state)
    return fr, g


def _arch_circle(half_w, spring, rise):
    R = (half_w ** 2 + rise ** 2) / (2 * rise)
    cz = spring + rise - R
    a0 = math.asin(half_w / R)
    return R, cz, a0


def arch_point(t, half_w, spring, rise, off=0.0):
    """拱上参数 t（0=左起拱点，1=右起拱点）处的点，off 沿法线向外偏移。返回 (x, z)。"""
    R, cz, a0 = _arch_circle(half_w, spring, rise)
    a = -a0 + 2 * a0 * t
    return ((R + off) * math.sin(a), cz + (R + off) * math.cos(a))


def arch_patch(name, half_w, spring, rise, t0, t1, y0, y1, thick=0.2, off=0.0, m="m_corrugated", n=4,
               parent=None, state=None):
    """拱形屋面上的一块板：横向 t0~t1，纵向 y0~y1（沿 Y 方向），厚 thick，off 是离拱面的距离。"""
    bm = bmesh.new()
    inner, outer = [], []
    for i in range(n + 1):
        t = t0 + (t1 - t0) * i / n
        xi, zi = arch_point(t, half_w, spring, rise, off)
        xo, zo = arch_point(t, half_w, spring, rise, off + thick)
        inner.append(((xi, y0, zi), (xi, y1, zi)))
        outer.append(((xo, y0, zo), (xo, y1, zo)))
    vi = [(bm.verts.new(a), bm.verts.new(b)) for a, b in inner]
    vo = [(bm.verts.new(a), bm.verts.new(b)) for a, b in outer]
    for i in range(n):
        bm.faces.new((vo[i][0], vo[i + 1][0], vo[i + 1][1], vo[i][1]))
        bm.faces.new((vi[i][1], vi[i + 1][1], vi[i + 1][0], vi[i][0]))
        bm.faces.new((vi[i][0], vi[i + 1][0], vo[i + 1][0], vo[i][0]))
        bm.faces.new((vo[i][1], vo[i + 1][1], vi[i + 1][1], vi[i][1]))
    bm.faces.new((vi[0][0], vo[0][0], vo[0][1], vi[0][1]))
    bm.faces.new((vi[n][1], vo[n][1], vo[n][0], vi[n][0]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj_from_bm(name, bm, m, (0, 0, 0), (0, 0, 0), parent, state)


def arch_band(name, half_w, spring, rise, width, thick, y, legs=True, m="m_concrete_trim", n=32, parent=None, state=None,
              off=0.0):
    """拱形门框 / 拱肋：沿拱的一条带，宽 width（沿 Y），厚 thick（沿法线向外）。legs=True 时两头带竖腿到地面。"""
    pts_in = [arch_point(i / n, half_w, spring, rise, off) for i in range(n + 1)]
    pts_out = [arch_point(i / n, half_w, spring, rise, off + thick) for i in range(n + 1)]
    if legs:
        poly = [(pts_out[0][0], 0)] + pts_out + [(pts_out[-1][0], 0), (pts_in[-1][0], 0)] + pts_in[::-1] + [(pts_in[0][0], 0)]
    else:
        poly = pts_out + pts_in[::-1]
    return prism(name, poly, width, (0, y - width / 2, 0), m, "XZ", parent, state)


# ---------------------------------------------------------------- 导出
def export_glb(root, path, states=None):
    """把 root 和它的子物体导出成 .glb。states 给了就只导出 state 属性为空或在其中的子物体。
    导出时根节点临时放回原点。"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    old = root.matrix_world.copy()
    root.matrix_world = Matrix.Identity(4)
    bpy.ops.object.select_all(action="DESELECT")
    sel = [root]
    for c in root.children_recursive:
        st = c.get("state")
        if states is None or st is None or st in states:
            sel.append(c)
    hidden = []
    for o in sel:
        if o.hide_get() or o.hide_viewport:
            hidden.append((o, o.hide_get(), o.hide_viewport))
            o.hide_set(False)
            o.hide_viewport = False
        o.select_set(True)
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_extras=True, export_yup=True)
    for o, h1, h2 in hidden:
        o.hide_set(h1)
        o.hide_viewport = h2
    root.matrix_world = old
    bpy.ops.object.select_all(action="DESELECT")


def show_state(root, state):
    """在 Blender 里切换显示的状态（ruin / repaired …），没标状态的物体一直显示。"""
    for c in root.children_recursive:
        st = c.get("state")
        if st is not None and st != "placeholder":
            vis = st == state
            c.hide_set(not vis)
            c.hide_viewport = not vis
            c.hide_render = not vis


def merge_by_material(root):
    """把根节点下的零件按（状态, 材质）合并成少数几个物体，Godot 里节点和绘制次数更少。"""
    groups = {}
    for c in list(root.children):
        if c.type != "MESH" or c.children:
            continue
        key = (c.get("state"), c.data.materials[0].name if c.data.materials else "")
        groups.setdefault(key, []).append(c)
    for (st, mn), objs in groups.items():
        o = join(objs, f"{root.name}_{mn}" + (f"_{st}" if st else ""))
        if st:
            o["state"] = st


def export_auto(root, folder):
    """按资产里出现的状态自动导出：有状态的每个状态一个文件（名字_状态.glb），没有就一个文件。"""
    states = sorted({c.get("state") for c in root.children_recursive if c.get("state") not in (None, "placeholder")})
    out = []
    if not states:
        p = os.path.join(folder, root.name + ".glb")
        export_glb(root, p, states=[])
        out.append(p)
    for st in states:
        p = os.path.join(folder, f"{root.name}_{st}.glb")
        export_glb(root, p, states=[st])
        out.append(p)
    return out


def instance(asset_name, loc, rot_z=0.0, coll=None, name=None):
    """在摆放预览里放一个资产的实例（不复制网格）。"""
    src = bpy.data.collections[asset_name]
    o = bpy.data.objects.new(name or asset_name + "_inst", None)
    o.instance_type = "COLLECTION"
    o.instance_collection = src
    o.location = loc
    o.rotation_euler = (0, 0, rot_z)
    (coll or bpy.context.scene.collection).objects.link(o)
    return o


def layout_collection(name):
    c = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if c.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(c)
    return c


def hide_masters(names):
    lc = bpy.context.view_layer.layer_collection
    for n in names:
        if n in lc.children:
            lc.children[n].exclude = True


def placeholder(name, size, loc, note, parent=None):
    """Tripo 物件的位置占位（半透明紫色方块），导出时不带。"""
    o = box(name, size, loc, "m_placeholder", parent=parent, base=True)
    o["tripo"] = note
    o["state"] = "placeholder"
    o.display_type = "WIRE"
    return o


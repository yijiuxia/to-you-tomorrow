# A-03 维修站机库（《美术拆件_A维修站》3.1 + 拆件图/a_hangar_views.png、a_repair_parts.png 01/02/04）
# 已按 75% 缩小：总宽约 27 米、深 21 米、高约 9.75 米；附楼宽 4.5 米、高 5.6 米。
# 门洞按文档 3.1 的 75% 版（约 9×5.25 米）。想改回原尺寸 12×7，把 DOOR_W / DOOR_H 改掉重跑即可。
# 正面朝 -Y。状态：ruin（废墟）/ repaired（修好），同一套骨架，靠 state 属性区分零件。
import math, random
from mathutils import Vector
import tyt_lib as L

S = 0.75
HW = 23.4 * S / 2          # 主厅半宽 8.775
D = 28 * S                 # 深 21
Y0, Y1 = -D / 2, D / 2
SPRING = 7.5 * S           # 起拱高度 5.625（= 附楼高度）
RISE = 13 * S - SPRING     # 拱高 4.125，顶高 9.75
WALL = 0.4
ANX_W = 6 * S              # 附楼宽 4.5
ANX_D = D - 2.0            # 附楼比主厅前后各短 1 米（俯视图）
ANX_H = SPRING
DOOR_W, DOOR_H = 12 * S, 7 * S
ROOF_T = 0.22
BAYS = 7
STRIPS = 8


def build():
    root = L.begin_asset("a_hangar")
    rnd = random.Random(3)

    # ---------------- 主厅前后山墙
    arch = L.arch_profile(HW, SPRING, RISE, 32)
    poly = [(-HW, 0), (HW, 0)] + arch[::-1]
    front = L.prism("hangar_front_wall", poly, WALL, (0, Y0, 0), "m_concrete")
    L.cut(front, L.cutter_box((DOOR_W, 2, DOOR_H), (0, Y0, DOOR_H / 2)))
    win_x = (HW + DOOR_W / 2) / 2 + 0.2
    win_w, win_h, win_z = 2.3 * S, 4.1 * S, 2.3 * S
    for sx in (-1, 1):
        L.cut(front, L.cutter_box((win_w, 2, win_h), (sx * win_x, Y0, win_z + win_h / 2)))
        L.window(f"win_front_{sx}", win_w, win_h, (sx * win_x, Y0 + WALL / 2, win_z), "-Y", mullions=(2, 3))
    back = L.prism("hangar_back_wall", poly, WALL, (0, Y1 - WALL, 0), "m_concrete")
    # 前后厚拱框（正视图里凸出来的一圈粗边）
    L.arch_band("hangar_front_band", HW - 0.3, SPRING, RISE, 1.2, 0.9, Y0 - 0.1, legs=True)
    L.arch_band("hangar_back_band", HW - 0.3, SPRING, RISE, 1.0, 0.9, Y1, legs=True)
    # 主厅两侧墙（被附楼挡住大部分，前后各露 1 米）
    for sx in (-1, 1):
        L.box(f"hangar_side_wall_{sx}", (WALL, D, SPRING), (sx * (HW - WALL / 2), 0, 0), "m_concrete", base=True)

    # 主厅地面（屋顶破洞里能看到）
    L.box("hangar_floor", (HW * 2 - 0.4, D - 0.8, 0.1), (0, 0, 0), "m_concrete_dark", base=True)

    # ---------------- 门框、浅内景
    fr = []
    ft = 0.45
    fr.append(L.box("door_frame_t", (DOOR_W + ft * 2, 0.6, ft), (0, Y0 - 0.15, DOOR_H + ft / 2), "m_concrete_trim"))
    for sx in (-1, 1):
        fr.append(L.box("door_frame_s", (ft, 0.6, DOOR_H), (sx * (DOOR_W / 2 + ft / 2), Y0 - 0.15, DOOR_H / 2), "m_concrete_trim"))
    L.join(fr, "door_frame")
    build_interior()
    # 门两侧的橙色壁灯：修好时亮
    for sx in (-1, 1):
        x = sx * (DOOR_W / 2 + ft + 0.35)
        L.box(f"door_lamp_on_{sx}", (0.18, 0.12, 0.9), (x, Y0 - 0.1, 1.2), "m_light_warm", base=True, state="repaired")
        L.box(f"door_lamp_off_{sx}", (0.18, 0.12, 0.9), (x, Y0 - 0.1, 1.2), "m_metal_dark", base=True, state="ruin")
    # 招牌底板（文字以后用贴纸 d_sign_a03）
    sign_z = DOOR_H + 1.2
    L.box("sign_a03", (4.0, 0.12, 0.9), (0, Y0 - 0.06, sign_z), "m_metal_dark", base=True)

    # ---------------- 屋面
    roof_y0, roof_y1 = Y0 + 1.1, Y1 - 0.9
    bay = (roof_y1 - roof_y0) / BAYS
    sky_strips = (2, 5)
    for b in range(BAYS):
        ya, yb = roof_y0 + bay * b, roof_y0 + bay * (b + 1)
        for s in range(STRIPS):
            ta, tb = s / STRIPS, (s + 1) / STRIPS
            nm = f"roof_{b}_{s}"
            if s in sky_strips:
                # 天窗：中间玻璃，两头一点铁皮
                inset = bay * 0.22
                L.arch_patch(nm + "_a", HW, SPRING, RISE, ta, tb, ya, ya + inset, ROOF_T, 0, "m_corrugated")
                L.arch_patch(nm + "_b", HW, SPRING, RISE, ta, tb, yb - inset, yb, ROOF_T, 0, "m_corrugated")
                broken = rnd.random() < 0.5
                L.arch_patch(nm + "_glass", HW, SPRING, RISE, ta + 0.01, tb - 0.01, ya + inset, yb - inset, 0.06, 0.08,
                             "m_glass", n=2, state=None if not broken else "repaired")
                L.arch_patch(nm + "_skyframe", HW, SPRING, RISE, ta, tb, ya + inset, yb - inset, ROOF_T, 0, "m_metal_paint", n=2,
                             state="__frame__")
            else:
                missing = rnd.random() < 0.45 and 0 < s < STRIPS - 1
                L.arch_patch(nm, HW, SPRING, RISE, ta, tb, ya, yb, ROOF_T, 0, "m_corrugated", state="repaired" if missing else None)
                if missing:
                    # 废墟版：破洞边上留半块翘起的残片
                    L.arch_patch(nm + "_scrap", HW, SPRING, RISE, ta, ta + (tb - ta) * 0.35, ya, ya + bay * 0.5, ROOF_T, 0,
                                 "m_metal_rust", state="ruin")
    # 天窗框改成真正的“框”：删掉占位的整块框（只保留玻璃两边的窄条）
    import bpy
    for o in list(root.children):
        if o.get("state") == "__frame__":
            bpy.data.objects.remove(o, do_unlink=True)
    for b in range(BAYS):
        ya, yb = roof_y0 + bay * b, roof_y0 + bay * (b + 1)
        inset = bay * 0.22
        for s in sky_strips:
            ta, tb = s / STRIPS, (s + 1) / STRIPS
            L.arch_patch(f"sky_side_{b}_{s}a", HW, SPRING, RISE, ta, ta + 0.012, ya + inset, yb - inset, ROOF_T + 0.08, 0, "m_metal_paint", n=1)
            L.arch_patch(f"sky_side_{b}_{s}b", HW, SPRING, RISE, tb - 0.012, tb, ya + inset, yb - inset, ROOF_T + 0.08, 0, "m_metal_paint", n=1)
    # 屋顶下的檩条（废墟版从破洞里能看到）
    for k in range(1, STRIPS * 2):
        t = k / (STRIPS * 2)
        x, z = L.arch_point(t, HW, SPRING, RISE, -0.18)
        L.box(f"purlin_{k}", (0.16, roof_y1 - roof_y0, 0.16), (x, (roof_y0 + roof_y1) / 2, z), "m_metal_rust")
    # 横向拱肋（每个开间一道，压在屋面上）
    for b in range(BAYS + 1):
        y = roof_y0 + bay * b
        L.arch_band(f"rib_{b}", HW, SPRING, RISE, 0.3, 0.16, y, legs=False, m="m_metal_paint", off=ROOF_T)
    # 屋面纵向黄色检修栏杆（俯视图里的黄线）
    for k in (1, 3, 5, 7):
        t = k / STRIPS
        x, z = L.arch_point(t, HW, SPRING, RISE, ROOF_T + 0.25)
        L.polyline_tube(f"roof_rail_{k}", [(x, roof_y0, z), (x, roof_y1, z)], 0.04, "m_yellow_paint")
    # 前拱框顶上的黄色护栏（正视图）
    pts = [(x, Y0 - 0.1, z) for (x, z) in [L.arch_point(i / 20, HW - 0.3, SPRING, RISE, 0.9) for i in range(1, 20)]]
    L.railing("front_arch_rail", pts, h=0.9, post_gap=1.6)
    pts = [(x, Y1, z) for (x, z) in [L.arch_point(i / 20, HW - 0.3, SPRING, RISE, 0.9) for i in range(1, 20)]]
    L.railing("back_arch_rail", pts, h=0.9, post_gap=1.6)
    # 侧面爬梯（右侧视图左端）
    lx, lz = HW + 0.2, SPRING
    lad = [L.beam("ladder_l", (lx, Y0 + 1.6, ANX_H + 0.25), (lx - 1.4, Y0 + 1.6, ANX_H + 3.4), 0.06, m="m_yellow_paint", round_=True),
           L.beam("ladder_r", (lx, Y0 + 2.2, ANX_H + 0.25), (lx - 1.4, Y0 + 2.2, ANX_H + 3.4), 0.06, m="m_yellow_paint", round_=True)]
    for k in range(1, 8):
        f = k / 8
        a = Vector((lx, Y0 + 1.6, ANX_H + 0.25)).lerp(Vector((lx - 1.4, Y0 + 1.6, ANX_H + 3.4)), f)
        lad.append(L.beam("rung", a, a + Vector((0, 0.6, 0)), 0.04, m="m_yellow_paint", round_=True))
    L.join(lad, "roof_ladder")

    # ---------------- 两侧附楼
    for sx in (-1, 1):
        build_annex(sx)

    # ---------------- 墙脚、管子、路桩
    plinth = []
    plinth.append(L.box("plinth_f", (HW * 2 + ANX_W * 2 + 0.2, 0.15, 0.4), (0, Y0 - 0.05, 0), "m_concrete_dark", base=True))
    plinth.append(L.box("plinth_b", (HW * 2 + ANX_W * 2 + 0.2, 0.15, 0.4), (0, Y1 + 0.05, 0), "m_concrete_dark", base=True))
    L.join(plinth, "plinth")
    ox = HW + ANX_W
    pipes = []
    for sx in (-1, 1):
        for y in (-ANX_D / 2 + 0.25, ANX_D / 2 - 0.25):
            pipes.append(L.beam("downpipe", (sx * (ox + 0.12), y, 0.2), (sx * (ox + 0.12), y, ANX_H + 0.2), 0.14, m="m_yellow_paint", round_=True))
    # 左附楼正面横管 + 右侧视图里的竖管
    pipes.append(L.beam("pipe_h", (-ox + 0.3, -ANX_D / 2 - 0.15, 3.4), (-HW - 0.2, -ANX_D / 2 - 0.15, 3.4), 0.14, m="m_yellow_paint", round_=True))
    pipes.append(L.beam("pipe_v", (-ox + 0.3, -ANX_D / 2 - 0.15, 0.3), (-ox + 0.3, -ANX_D / 2 - 0.15, 3.4), 0.14, m="m_yellow_paint", round_=True))
    for y in (-3.4, 3.4):
        pipes.append(L.beam("pipe_side", (ox + 0.12, y, 0.2), (ox + 0.12, y, ANX_H + 0.2), 0.12, m="m_yellow_paint", round_=True))
    L.join(pipes, "pipes")
    # 配电箱（左附楼正面）
    L.box("wall_cabinet", (0.9, 0.4, 1.6), (-ox + 1.3, -ANX_D / 2 - 0.2, 0.1), "m_metal_paint", base=True)
    bol = []
    for x in (-ox + 0.3, -HW - 0.6, -DOOR_W / 2 - 0.9, DOOR_W / 2 + 0.9, HW + 0.6, ox - 0.3):
        bol.append(L.cyl("bollard", 0.13, 0.9, (x, Y0 - 0.9, 0), "m_yellow_paint", seg=10))
    L.join(bol, "bollards")
    return root


def build_annex(sx):
    cx = sx * (HW + ANX_W / 2)
    ox = sx * (HW + ANX_W)
    ya, yb = -ANX_D / 2, ANX_D / 2
    seg = ANX_D / 3
    tag = "l" if sx < 0 else "r"
    # 正面墙
    f = L.box(f"annex_{tag}_front", (ANX_W, WALL, ANX_H), (cx, ya + WALL / 2, 0), "m_concrete", base=True)
    if sx > 0:
        w, h = 3.5 * S, 3.4 * S
        L.cut(f, L.cutter_box((w, 2, h), (cx, ya, 1.4 + h / 2)))
        L.window("win_annex_r_front", w, h, (cx, ya + WALL / 2, 1.4), "-Y", mullions=(4, 3))
    # 背面墙 + 窗
    bk = L.box(f"annex_{tag}_back", (ANX_W, WALL, ANX_H), (cx, yb - WALL / 2, 0), "m_concrete", base=True)
    w, h = 3.0 * S, 3.0 * S
    L.cut(bk, L.cutter_box((w, 2, h), (cx, yb, 1.4 + h / 2)))
    L.window(f"win_annex_{tag}_back", w, h, (cx, yb - WALL / 2, 1.4), "+Y", mullions=(4, 3))
    # 外侧墙分三段，每段一扇窗；左附楼中段在废墟版塌掉
    w, h, z = 4.5 * S, 3.0 * S, 2.1 * S
    for i in range(3):
        yc = ya + seg * (i + 0.5)
        collapsible = (sx < 0 and i == 1)
        wall = L.box(f"annex_{tag}_side_{i}", (WALL, seg, ANX_H), (ox - sx * WALL / 2, yc, 0), "m_concrete", base=True,
                     state="repaired" if collapsible else None)
        L.cut(wall, L.cutter_box((2, w, h), (ox, yc, z + h / 2)))
        fr, gl = L.window(f"win_annex_{tag}_side_{i}", w, h, (ox - sx * WALL / 2, yc, z), "-X" if sx < 0 else "+X", mullions=(4, 3))
        if collapsible:
            fr["state"] = "repaired"
            gl["state"] = "repaired"
            # 塌掉的版本：参差不齐的断墙
            pts = [(-seg / 2, 0), (seg / 2, 0), (seg / 2, 3.6), (seg * 0.3, 2.9), (seg * 0.18, 1.6), (0.0, 2.2),
                   (-seg * 0.15, 1.1), (-seg * 0.32, 2.5), (-seg / 2, 4.6)]
            L.prism(f"annex_{tag}_side_{i}_broken", pts, WALL, (ox, yc, 0), "m_concrete", plane="YZ",
                    state="ruin", rot=(0, 0, 0)).location.x = ox - WALL if sx > 0 else ox
    # 内侧（贴着主厅）不用墙；屋面分三段，左附楼中段废墟版没有
    for i in range(3):
        yc = ya + seg * (i + 0.5)
        L.box(f"annex_{tag}_roof_{i}", (ANX_W, seg, 0.25), (cx, yc, ANX_H - 0.25), "m_concrete_dark", base=True,
              state="repaired" if (sx < 0 and i == 1) else None)
    # 女儿墙
    par = []
    par.append(L.box("par", (ANX_W, 0.25, 0.3), (cx, ya + 0.125, ANX_H), "m_concrete_trim", base=True))
    par.append(L.box("par", (ANX_W, 0.25, 0.3), (cx, yb - 0.125, ANX_H), "m_concrete_trim", base=True))
    L.join(par, f"annex_{tag}_parapet")
    L.box(f"annex_{tag}_parapet_side", (0.25, ANX_D, 0.3), (ox - sx * 0.125, 0, ANX_H), "m_concrete_trim", base=True,
          state="repaired" if sx < 0 else None)
    if sx < 0:
        for i in (0, 2):
            L.box(f"annex_l_parapet_side_{i}", (0.25, seg, 0.3), (ox + 0.125, ya + seg * (i + 0.5), ANX_H), "m_concrete_trim",
                  base=True, state="ruin")
    # 屋顶黄色护栏
    i_ = 0.25
    x_in, x_out = sx * (HW + 0.1), ox - sx * i_
    pts = [(x_in, ya + i_, ANX_H + 0.3), (x_out, ya + i_, ANX_H + 0.3), (x_out, yb - i_, ANX_H + 0.3), (x_in, yb - i_, ANX_H + 0.3)]
    if sx < 0:
        L.railing("annex_l_rail", pts, h=1.0, post_gap=1.5, state="repaired")
        L.railing("annex_l_rail_a", pts[:2] + [(x_out, ya + seg - 0.3, ANX_H + 0.3)], h=1.0, state="ruin")
        L.railing("annex_l_rail_b", [(x_out, yb - seg + 0.3, ANX_H + 0.3)] + pts[2:], h=1.0, state="ruin")
    else:
        L.railing("annex_r_rail", pts, h=1.0, post_gap=1.5)
    # 里面填一个暗色内胆：窗户看进去是黑的，塌墙处也不会看穿
    for i in range(3):
        yc = ya + seg * (i + 0.5)
        L.box(f"annex_{tag}_inner_{i}", (ANX_W - 1.0, seg - 0.4, ANX_H - 0.6), (cx, yc, 0.05), "m_interior_dark", base=True,
              state="repaired" if (sx < 0 and i == 1) else None)
    if sx < 0:
        L.box("annex_l_floor", (ANX_W - 0.4, seg, 0.1), (cx, 0, 0), "m_concrete_dark", base=True, state="ruin")


def build_interior():
    """门后 4.5 米的浅内景（拆件图 04）：假后墙、大圆筒设备、工作台、屏幕、顶灯。"""
    y0 = Y0 + WALL
    depth = 4.5
    yb = y0 + depth
    iw = DOOR_W + 2.0
    ih = DOOR_H + 1.6
    L.box("int_floor", (iw, depth, 0.05), (0, y0 + depth / 2, 0), "m_floor", base=True)
    L.box("int_back", (iw, 0.3, ih), (0, yb, 0), "m_interior_wall", base=True)
    for sx in (-1, 1):
        L.box("int_side", (0.3, depth, ih), (sx * iw / 2, y0 + depth / 2, 0), "m_interior_wall", base=True)
    L.box("int_ceiling", (iw, depth, 0.3), (0, y0 + depth / 2, ih), "m_metal_dark", base=True)
    # 后墙上的窗（亮着的高窗）
    for x in (-3.0, 0, 3.0):
        L.window(f"int_win_{x}", 1.4, 1.1, (x, yb - 0.16, ih - 2.0), "-Y", mullions=(3, 2))
    # 墙上的钢立柱
    for x in (-iw / 2 + 0.4, -1.5, 1.5, iw / 2 - 0.4):
        L.box("int_column", (0.3, 0.3, ih), (x, yb - 0.3, 0), "m_yellow_paint", base=True)
    # 顶灯：修好亮 / 废墟灭
    for x in (-2.5, 2.5):
        L.box(f"int_light_on_{x}", (1.6, 0.25, 0.1), (x, y0 + 2.0, ih - 0.1), "m_light_warm", base=True, state="repaired")
        L.box(f"int_light_off_{x}", (1.6, 0.25, 0.1), (x, y0 + 2.0, ih - 0.1), "m_metal_dark", base=True, state="ruin")
    # 大圆筒设备（横放）+ 黄色支架
    cx, cy = 2.0, yb - 1.7
    L.cyl("int_drum", 1.05, 2.8, (cx - 1.4, cy, 1.55), "m_metal_paint", axis="X", seg=24)
    L.cyl("int_drum_cap", 0.8, 0.2, (cx + 1.4, cy, 1.55), "m_metal_dark", axis="X", seg=24)
    for dx in (-1.2, 0.0, 1.2):
        L.beam("drum_band", (cx + dx, cy - 1.07, 1.55), (cx + dx, cy + 1.07, 1.55), 0.12, 0.12, "m_metal_rust")
    st = []
    st.append(L.box("stand", (3.0, 1.6, 0.15), (cx, cy, 0.35), "m_yellow_paint", base=True))
    for dx in (-1.3, 1.3):
        for dy in (-0.6, 0.6):
            st.append(L.box("stand_leg", (0.12, 0.12, 0.4), (cx + dx, cy + dy, 0), "m_yellow_paint", base=True))
    L.join(st, "int_stand")
    # 工作台 + 屏幕
    wx, wy = -3.0, yb - 1.0
    L.box("int_desk", (2.2, 0.8, 0.08), (wx, wy, 0.85), "m_metal_paint", base=True)
    L.box("int_desk_body", (2.1, 0.7, 0.85), (wx, wy, 0), "m_metal_dark", base=True)
    L.box("int_screen_frame", (1.5, 0.08, 0.95), (wx, wy + 0.25, 1.1), "m_metal_dark", base=True)
    L.box("int_screen_on", (1.35, 0.02, 0.8), (wx, wy + 0.2, 1.18), "m_light_cyan", base=True, state="repaired")
    L.box("int_screen_off", (1.35, 0.02, 0.8), (wx, wy + 0.2, 1.18), "m_screen_off", base=True, state="ruin")
    # 几个小箱子、黄黑警示牌
    for (x, y, s) in ((4.7, yb - 3.0, 0.6), (4.75, yb - 3.7, 0.5), (4.6, yb - 0.6, 0.7)):
        L.box("int_box", (s, s, s), (x, y, 0), "m_crate", base=True)
    L.box("int_sign", (0.8, 0.05, 0.6), (4.4, yb - 0.17, 1.4), "m_yellow_paint", base=True)
    # 仓库货架（靠左墙，正面朝屋里）+ 旧种子罐的位置标记。
    # ARK-01 从门进来左转就能走到架子前：架子前有约 1.6×2.8 米的空地（门洞左边到工作台之间）。
    import math as _m, bpy as _bpy
    import build_kit as K
    sx_, sy_ = -iw / 2 + 0.15 + 0.3, yb - 2.0
    K.shelf_parts((sx_, sy_, 0), _m.pi / 2, "int_shelf")
    for (dz, dy, s) in ((0.65, -0.5, 0.4), (0.65, 0.2, 0.35), (1.15, -0.3, 0.45)):
        L.box("int_shelf_bin", (0.45, s, s * 0.8), (sx_, sy_ + dy, dz), "m_crate", base=True)
    mk = _bpy.data.objects.new("marker_seed_can", None)
    mk.empty_display_type = "SINGLE_ARROW"
    mk.empty_display_size = 0.4
    mk.location = (sx_ - 0.05, sy_ + 0.55, 0.15)
    mk["note"] = "旧种子罐 kit_seed_can 放在这里（货架最底层）"
    L._link(mk)


if __name__ == "__main__":
    pass




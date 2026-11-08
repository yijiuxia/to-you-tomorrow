# A 维修站总入口：搭全部模型 → 导出 .glb → 摆整区预览 → 存 .blend
# 在 Blender 里运行：import build_a_main; build_a_main.run()
import os, importlib
import bpy
import tyt_lib as L
import build_a_hangar as H
import build_kit as K
import build_a_area as A

for m in (L, H, K, A):
    importlib.reload(m)

OUT_A = os.path.join(L.MODELS, "a_repair")
OUT_KIT = os.path.join(L.MODELS, "kit")


def layout(state="ruin"):
    lay = L.layout_collection("LAYOUT_A")
    L._cur_coll, L._cur_root = lay, None
    G = A.G
    I = lambda n, gx, gz, rz=0.0: L.instance(n, G(gx, gz), rz, lay)
    # 机库：正面朝北（Godot +z），门口对着前广场，主体伸到地图南边外面
    I("a_hangar", 26, -4.5)
    # 旧种子罐：放在机库浅内景左边货架的最底层（位置 = 机库位置 + marker_seed_can）
    mk = bpy.data.objects["marker_seed_can"]
    L.instance("kit_seed_can", (26 + mk.location.x, 4.5 + mk.location.y, mk.location.z), 0.4, lay)
    # 前广场小道具（参考拆件图 08 的摆法）
    I("kit_crate_l", 13, 9, 0.2)
    I("kit_crate_m", 15.5, 8.2, -0.1)
    I("kit_crate_s", 14.2, 10.6, 0.5)
    I("kit_crate_m", 9, 24, 0.0)
    I("kit_crate_s", 10.4, 24.5, 0.3)
    I("kit_pipe_stack", 11, 21, 1.4)
    I("kit_pipe_stack", 14.5, 22, 1.6)
    I("kit_power_cabinet", 34, 7.2, 3.14159)
    I("kit_canopy", 44, 12, 0.1)
    I("kit_canopy", 48.5, 14, -0.15)
    I("kit_hanging_crate", 40.5, 4.0, 0.3)
    for i, gx in enumerate((18, 20, 22)):
        I("kit_railing", gx, 24.5)
    I("kit_railing_corner", 31, 24.5, 0)
    for gx in (23.5, 28.5):
        I("kit_bollard", gx, 25.5)
    for gx, gz in ((20, 17), (21.2, 17.6), (32, 18.4)):
        I("kit_traffic_cone", gx, gz)
    for gx in (6, 22, 38, 54):
        I("kit_street_lamp", gx, 33.4, 3.14159)
    I("kit_flag", 10.5, 7.5)
    I("kit_flag", 41.5, 7.5)
    I("a_rain_tank", 54, 4)
    I("a_ground", 0, 0)
    # 远景：高架沿弧线、残楼一圈、塔
    import math
    for k in range(20):
        a = math.radians(-70 + k * 7.24)   # 半径 95 米时每段弧长正好约 12 米
        cx, cz, R = 30, 40, 95
        gx, gz = cx + R * math.sin(a), cz - R * math.cos(a)
        I("a_viaduct_seg", gx, gz, -a)
    for (n, gx, gz, rz) in ((1, -30, -10, 0.3), (2, -35, 20, -0.2), (3, -28, 45, 0.1), (2, 92, -5, 0.5),
                            (1, 95, 25, -0.4), (3, 90, 50, 0.2), (1, 10, -80, 0.0), (3, 55, -85, 0.3)):
        I(f"bg_ruin_{n}", gx, gz, rz)
    I("bg_tower", 80, -45)
    # Tripo 物件占位（紫色线框）
    ph = L.placeholder
    ph("TA02_crane", (6, 4, 7), G(42, 1), "TA02 吊车")
    ph("TA03_tarp_pile", (6, 4, 2.5), G(49, 23), "TA03/TA04 盖布货堆（材料堆 material_pile）")
    ph("TA07_collapsed_wall", (18, 3, 4), G(31, 47), "TA07 塌墙段（北边的断墙 wall）")
    ph("TA05_rubble_large", (5, 4, 1.8), G(13.5, -1), "TA05 大碎石堆（机库左侧塌墙下）")
    ph("TA05_rubble_plaza", (14, 10, 1.5), G(26, 14), "TA05/TA06 前广场废墟（plaza）")
    ph("TA06_rubble_small", (2, 2, 0.8), G(36, 21), "TA06 小碎石堆")
    ph("ruin_old_tank", (8, 8, 6), G(51, 48), "旧储罐废墟 tank：可以用 B 区储罐 b_tank 缩小")
    ph("TB05_cable_reel", (1.4, 1.4, 1.2), G(17, 11), "TB05 电缆盘")
    for i, (gx, gz) in enumerate(((2, 26), (58, 28), (4, 55), (57, 54))):
        ph(f"TA08_rock_{i}", (5, 4, 3), G(gx, gz), "TA08～10 岩石")
    for i, (gx, gz) in enumerate(((5, 12), (56, 40))):
        ph(f"TA11_tree_{i}", (4, 4, 6), G(gx, gz), "TA11/TA12 树（修好以后才摆）")
    return lay


def run(state="ruin", export=True):
    L.clear_scene()
    names = []
    r = H.build(); names.append(r.name)
    L.merge_by_material(r)
    for n, fn in K.KIT.items():
        names.append(fn().name)
    for n, r in A.build_all().items():
        names.append(n)
    files = []
    if export:
        for n in names:
            root = bpy.data.objects[n]
            folder = OUT_KIT if n.startswith("kit_") else OUT_A
            files += L.export_auto(root, folder)
    for n in names:
        L.show_state(bpy.data.objects[n], state)
    layout(state)
    L.hide_masters(names)
    os.makedirs(L.SOURCE, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(L.SOURCE, "a_repair.blend"))
    return files

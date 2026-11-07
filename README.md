# 致明日的你 / To You, Tomorrow

Godot 4 项目。策划文档在 Obsidian 库 `wiki/projects/致明日的你/` 和项目文件夹 `致明日的你策划/` 里。

## 文件夹

| 文件夹 | 放什么 | 谁来改 |
| --- | --- | --- |
| `data/` | 数值表格：课程、属性、建筑、玩家态度、平衡参数 | 调数值时改这里 |
| `text/` | 界面文字，中英文各一列（第一列是编号） | 改界面文字时改这里 |
| `story/` | 剧情台词（Dialogue Manager 的 .dialogue 文件），按周分文件 | 改剧情时改这里 |
| `scripts/autoload/` | 全局模块：DataDB 读表格，GameState 存游戏状态 | 代码 |
| `scripts/systems/` | 各个系统：课程、聊天、建造、剧情、存档 | 代码 |
| `scenes/` | Godot 场景 | 编辑器里做 |
| `assets/` | 模型、贴图、声音 | 美术 |
| `addons/` | 插件（Dialogue Manager 装在这里） | 编辑器里装 |

## 改数值的注意事项

1. 用 Excel 或 WPS 打开 `data/` 里的 .csv 文件，改完**一定要另存为"CSV UTF-8"**。存成普通 CSV 会变成乱码，游戏读不出来。
2. 第一列是 id，不要改 id，只改后面的数字。
3. 想临时停用一行，在 id 前面加 `#`。
4. 每个 .csv 旁边有一个 .csv.import 文件，不要删。它告诉 Godot "这是数据表，不是翻译表"。

## 编号规则

文字一律用编号，和策划里的 `文案/00_目录.md` 一致：OP 开场 · WK 每周通用 · W1～W6 各周 · TJ 时间跳跃 · ED 结局与尾声 · CR 课程 · UI 界面 · FB 后备句 · SV 幸存者。

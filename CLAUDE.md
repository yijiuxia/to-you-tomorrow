# CLAUDE.md：给 AI 助手的项目说明

在这个项目里写代码、改数据之前，先读完本文件。

## 项目是什么

《致明日的你 / To You, Tomorrow》，Godot 4 的 3D 养成 + 建造探索游戏。
玩家养育一个在方舟上长大的女孩，和她一起遥控机器人 ARK-01 重建地球；她以为那只是一个游戏。
核心卖点：女孩由本地运行的小模型（Qwen 约 3B，GGUF）驱动，固定输出 JSON（reply、emotion、player_attitude、intent、options）。
**程序保存真实状态，模型只说话和打标签，不决定数值。**

策划文档不在这个仓库里：
- Obsidian 库 `C:\Users\ZJST\Documents\weili` 的 `wiki/projects/致明日的你/`（比赛版策划、完整世界观与剧情、demo文案）
- 项目文件夹 `致明日的你策划/`：`制作清单（草稿）.md`、`美术清单.md`、`文案/00_目录.md`、`进度记录.md`

改动和策划冲突时，先问，不要自己定。

## 和用户沟通

- 用户 yi 是编程新手。全部用中文，每次回复开头称呼"yi"。
- 少用术语，必须用时顺带解释。少贴大段代码，需要用户操作时给清楚的步骤。
- 写代码前先用通俗的话说明方案，等用户同意。较大的事给"效果最好"和"最省事"两个方案，并推荐一个。
- 做完后说明可能出问题的情况，以及用户怎么验证。
- 需求不清时先问 1～3 个问题，给选项，不要猜。

## 安全约束（必须遵守）

- 网文相关内容禁止写入 `C:\Users\ZJST\Documents\weili`，除非用户主动要求（游戏策划文档可以写进去）。
- 未经允许，禁止查看、搜索、读取 Codex 相关文件：`C:\Users\ZJST\.codex\`、`C:\Users\ZJST\Documents\Codex\`、`C:\Users\ZJST\AppData\Local\OpenAI\`。
- `E:\GODOT` 下的其他文件夹是别的项目，不要打开。

## 代码规则

1. **数据和代码分开**。数值只放 `data/*.csv`，文字只放 `text/` 和 `story/`。代码里不写死数字和中文句子。
2. **一个模块只管一件事**。全局模块在 `scripts/autoload/`：
   - `DataDB`：读 `data/` 的表格。`DataDB.row("courses", "mechanics")`、`DataDB.balance("work_units_per_week")`。
   - `Text`：读 `text/*.csv`，按编号取文字。`Text.t("UI-01-01")`，带占位符用 `Text.f("UI-01-05", {"week": 3})`。
   - `GameState`：属性、周数、年龄、认知状态（GAME / DOUBT / BELIEVE）、是否遇到幸存者、剧情标记。改属性一律用 `GameState.change_stat()`，它会按表格截断范围。
   - `ModelService`：加载模型、发话、检查回复，失败退回 FB- 后备句。
   - 规则放 `scripts/systems/`（不碰画面，能测试），地球规则是 `earth_world.gd`。地球的画面和操作放 `scripts/earth/`，其他界面放 `scripts/ui/`。还没做：剧情播放、存档。
3. **文字一律用编号**，和 `文案/00_目录.md` 一致：OP 开场 · WK 每周通用 · W1～W7 各周（W1 课程教学周，W2 起建造；W7A 遇到线、W7B 没遇到线）· TJ 时间跳跃 · ED 结局与尾声 · CR 课程 · UI 界面 · FB 后备句 · SV 幸存者。格式 `代号-段落-序号`，如 `W4-02-03`。改文字不改编号，删掉的编号不再用。
4. **数据表**：第一列是 id；`#` 开头的行跳过。每个 `data/*.csv` 和 `text/*.csv` 旁边必须有 `.csv.import`（内容 `importer="keep"`），否则 Godot 会把它当翻译表导入。新增表格时也要加，并把表名加进 `data_db.gd` 的 `TABLES` 或 `text.gd` 的 `FILES`。
5. 表格必须是 **UTF-8** 编码（Excel 要"另存为 CSV UTF-8"）。`DataDB` 会自动去掉 BOM。
6. 剧情用 Dialogue Manager 插件（装在 `addons/`），台词文件放 `story/`，按周分文件。
7. 模型调用要有后备：生成失败或超时，用 `FB-` 编号的固定句。
8. GDScript 用静态类型（`var x: int`、`:=`），注释用中文，写清楚"为什么"。

## 版本管理

- 仓库用 GitHub Desktop 管理，远程是用户的 GitHub 私有仓库。
- 每完成一个能运行的小步骤就提交一次，提交说明用中文写清楚改了什么。
- 不提交 `.godot/`（Godot 自动生成的缓存）。
- 模型文件（.gguf，几个 G）不要放进仓库。放在 `models/`，文件名写在 `data/balance.csv` 的 `model_file`；打包后放在游戏程序旁边的 `models/`。

## 当前进度

- 已有：文件夹结构、5 张数据表、DataDB、GameState、模型测试画面（`scenes/tests/model_test.tscn`）。
- 第 0 步已测：Qwen 3B + NobodyWho 13 可用，结果和遗留问题见 `docs/第0步技术验证结果.md`。聊天和决策用同一个模型（yi 已定）。
- 第 1 步：方块版流程能从第 1 周点到结局。流程规则在 `scripts/systems/`，画面在 `scripts/ui/`。改规则后跑 `scenes/tests/` 里的 unit_tests、earth_tests、playthrough_test，退出码 0 才算过。
- yi 试玩后定：属性（含性格、信任）都显示数字；属性的文字说明只在鼠标悬停时显示；课程直接写名字和属性变化，课程说明在悬停时显示。聊天里不显示情绪标签。demo 只有默认微笑和眨眼两个表情，其他表情以后开发；模型的 emotion 字段先保留不用。
- 第 2 步：A 区地球玩法能玩（全是方块，建模还没做好）：俯视放蓝图和清理、水电网络、恢复度、周结算、机器人寻路、第三人称 ARK-01、游戏滤镜。测试版按 F9 加满技能和材料，打包版没有这个键。
- yi 定：游戏共 7 周。第 1 周只有课程教学（小镇锁着），第 2 周早上才第一次结算课并开启建造教学，第 3 周后时间跳跃，第 7 周后结局。第 1 周不恢复体力，让课程数值核算保持不变。
- 下一步：按 `制作清单（草稿）.md`（2026-11-08 改成按系统模块）的顺序做：模块 3 → 4 → 5 → 6 → 8，文案到了做 7，模型到了做 9。yi 定：不再每一步停下来等试玩，每个模块写完跑自动测试，全部接起来后 yi 完整试玩一次。
- 文案正在重新讨论，代码里先用临时文字，编号保持一致。

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

## 多线程分工（yi 定，必须遵守）

几个线程同时写这个项目。每个线程开工前先读本节，只做自己的模块。模块编号见 `制作清单（草稿）.md`。

| 线程 | 负责的模块 | 只改这些文件 | 分支 |
| --- | --- | --- | --- |
| A 地球（总集成） | 4 地球建造、5 ARK-01、6 她影响建造；合并各线程 | `scripts/earth/`、`scripts/systems/earth_*.gd`、`data/earth_*.csv`、`data/buildings.csv`、`scenes/tests/earth_*`、`scripts/tests/earth_*` | `main` |
| B 人物 AI | 3 聊天、记忆、鲜活感 | `scripts/autoload/model_service.gd`、`scripts/systems/chat_*.gd`、`scripts/systems/memory_*.gd`、`scripts/ui/chat_screen.gd`、`scripts/ui/chat_presence.gd`、`scripts/ui/chat_comment.gd`、`scripts/ui/chat_event_panel.gd`、`scripts/ui/chat_story_input.gd`、`text/prompts/`、`data/model_*`、`data/chat_*`、`data/memory_*`、`tests/model_test/`、`scripts/tests/model_test.gd` | `thread/ai` |
| C 界面与流程 | 8 界面、存档、设置、英文切换；7 剧情播放器的框架（文案到了再填） | `scripts/ui/`（聊天画面除外）、`scripts/systems/save_*.gd`、`scripts/systems/story_*.gd`、`story/`、`addons/dialogue_manager/` | `thread/ui` |
| 策划线程 | 文案、训练数据（不写代码） | Obsidian 和项目文件夹里的策划文档 | — |

**共用文件**（大家都会碰）：`data/balance.csv`、`text/*.csv`、`scripts/autoload/game_state.gd`、`scripts/autoload/text.gd`、`scripts/main.gd`、`project.godot`、`CLAUDE.md`。规则：

1. 只在末尾**追加**自己的行或变量，不改、不删、不挪别人的。要改别人的，先在线程里说明，由 A 合并时处理。
2. 新编号用自己的号段，避免撞号：
   - `text/` 的 UI 编号：A 用 UI-13～UI-39，B 用 UI-40～UI-49，C 用 UI-50～UI-79。WK、FB 归 B；OP、W1～W7、TJ、ED、SV 由 C 的剧情框架接入。
   - `balance.csv` 的 id 前缀：A 用 `earth_`、`ark_`、`event_`；B 用 `model_`、`chat_`、`memory_`；C 用 `save_`、`ui_`、`story_`。
3. 中英文都要做：新加的文字两列都填。英文可以先写临时译文，但不能留空。

**分支和合并**：

1. B、C 必须在自己的工作树（Worktree）和分支里改，不直接改 `main`，也不改 E:\GODOT\to-you-tomorrow 这个文件夹里的文件（yi 的 Godot 编辑器开着它）。
2. 每完成一块能运行的就提交到自己的分支，提交说明用中文。
3. 合并到 `main` 由线程 A 做：先跑全部自动测试，退出码都是 0 才合并；冲突由 A 解决，拿不准的问 yi。
4. 工作树里没有大文件（不进仓库），开工时要自己准备：NobodyWho 的 dll 按 `addons/README.md` 放好；模型用 `--model=` 指到 `E:\GODOT\to-you-tomorrow\models\qwen3.5-2b-q4_k_m.gguf`，不要复制一份。

**测试**：

0. **所有自动测试都在后台跑，加 `--headless`，不要弹出 Godot 窗口**（yi 要求：弹窗会打断 yi 做事）。需要截图检查画面时才开窗口，并且先告诉 yi。
1. 不再每一步停下来等 yi 试玩。模块写完跑 `scenes/tests/` 里的自动测试，全部接起来后 yi 完整试玩一次。
2. 自己的模块要有自己的测试，加进 `scenes/tests/`。
3. 带模型的测试很占显卡，几个线程同时跑会变慢。能不带模型测的就不带（加 `--model=` 指向不存在的文件，会走后备句）。

## 当前进度

- 已有：文件夹结构、5 张数据表、DataDB、GameState、模型测试画面（`scenes/tests/model_test.tscn`）。
- 第 0 步已测：Qwen 3B + NobodyWho 13 可用，结果和遗留问题见 `docs/第0步技术验证结果.md`。聊天和决策用同一个模型（yi 已定）。
- 第 1 步：方块版流程能从第 1 周点到结局。流程规则在 `scripts/systems/`，画面在 `scripts/ui/`。改规则后跑 `scenes/tests/` 里的 unit_tests、earth_tests、ui_tests、chat_tests、playthrough_test（都加 `--headless`），退出码 0 才算过。
- yi 试玩后定：属性（含性格、信任）都显示数字；属性的文字说明只在鼠标悬停时显示；课程直接写名字和属性变化，课程说明在悬停时显示。聊天里不显示情绪标签。demo 只有默认微笑和眨眼两个表情，其他表情以后开发；模型的 emotion 字段先保留不用。
- 第 2 步：A 区地球玩法能玩（全是方块，建模还没做好）：俯视放蓝图和清理、水电网络、恢复度、周结算、机器人寻路、第三人称 ARK-01、游戏滤镜。测试版按 F9 加满技能和材料，打包版没有这个键。
- yi 定：游戏共 7 周。第 1 周只有课程教学（小镇锁着），第 2 周早上才第一次结算课并开启建造教学，第 3 周后时间跳跃，第 7 周后结局。第 1 周不恢复体力，让课程数值核算保持不变。
- 下一步：按 `制作清单（草稿）.md`（2026-11-08 改成按系统模块）和上面的「多线程分工」并行做；文案到了做 7，模型到了做 9。yi 定：不再每一步停下来等试玩，每个模块写完跑自动测试，全部接起来后 yi 完整试玩一次。
- 文案正在重新讨论，代码里先用临时文字，编号保持一致。
- yi 已定：存档只做每周自动存 + 继续；中英文都做；温室不管建没建完都进结局。

## 房间线程（2026-11-19，yi 的 11.12 新想法 4 项 + 科技树）

- 主界面中间换成 3D 方块房间（`scripts/room/room_view.gd`），通用交互：看说明 / 近看（右键退出）/ 开关（灯、灯罩、收书）/ 点她聊天 / 点平板 / 点舱门出电梯菜单。她主动开口时头上冒"!"。
- 平板（`tablet_panel.gd`）：窗景、音乐（没有素材，先程序合成和弦）、周记、地球情况、灯光、科技（她技能够了自动解锁，门槛和 buildings.csv 一致）。
- 场所（`place_screen.gd`）：机械室、温室、通讯室、人类保护区（只能沿过道走），A/D 左右走。第 7 周主界面多一个按钮去地下居民区（临时文字，世界观定了再换；条件在 `RoomRules.can_go_underground()`）。
- 规则在 `scripts/systems/room_rules.gd`，状态存在 `GameState.flags` 的 `room_` 开头的键里（随自动存档保存）。数据：`data/room_objects.csv`（物件和位置）、`places.csv`、`room_options.csv`、`tech.csv`；文字 `text/rm.csv`，编号前缀 RM；balance 前缀 `room_`。
- 测试 `scenes/tests/room_tests.tscn`（后台）；`room_shot.tscn` 会开窗口截图，跑前先告诉 yi。
- 注意：`--model=` 要写在 `--` 后面才生效（`... xxx.tscn -- --model=none.gguf`），否则会加载真模型。
- 2026-11-19 接了房间真模型：`assets/models/room/cabin.glb`（从 `E:\jianmo_test\致你\房间\cabin_v02_20261108.blend` 导出，贴图压到 1024、WebP；导出脚本思路：不带灯/相机/Orbit_View/Tripo 占位）。镜头对齐 blend 的 Cam_Main（places.csv 的 cam_x/cam_yaw/cam_fov）。能点的东西是盖在模型上的看不见的点击框（room_objects.csv 里 color 空着），开关要藏的零件写在 nodes 列。窗外星空和地球用 `assets/textures/room/`。她还是胶囊占位。
- 2026-11-19 界面：全部画面用 `scripts/ui/glass_theme.gd` 的玻璃面板样式（科技蓝，main.gd 设在根窗口上）。主界面 `hub_screen.gd` 照 yi 的参考图（`C:\Users\ZJST\Pictures\方舟\实际画面` 第 3 张）逐块做；图标是 `assets/ui/icons/*.svg`。平板和舱门不做按钮，只能点房间里的（yi 定）。
- 2026-11-19 文字编号：定稿 13_平板与房间、14_场所的文字在 `text/tb.csv`（TB、TT、RM、PL，按定稿编号）。房间线程自己写的界面文字改用 RT 前缀，放 `text/rt.csv`（原 rm.csv），不要再用 RM 写新东西。

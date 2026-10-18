森林旅人 0.1.0 — 2D 图形初版

开始：双击“开始游戏.command”。需要已经安装的 /Applications/Godot.app。
也可以在 Godot 导入本文件夹的 project.godot，然后按 F6/F5 运行。

WASD 或方向键：移动
E：交谈、拾取、开启出口
B：背包；点击“丢下 1”将多余材料放回地面
C：制作石剑（3 树枝 + 4 石头 + 3 草绳）
Esc：关闭面板或暂停
通关后 R：重新开始

目标：与营地向导交谈，制作石剑，找到三枚晶石，前往东北出口。
右上角小地图：白点是你，蓝点是晶石，黄点是出口。

这是探索玩法原型：简单几何图形、两个 NPC、湖水/房屋/树干碰撞、相机跟随、材料背包和制作、小任务与通关。
本版没有敌人、战斗、夜晚生存或存档。关闭窗口后进度重置。
后续版本可接入之前 Python 游戏的生存规则。

项目由 Godot 运行，不再是单个 Python 文件。
main.gd：主要游戏逻辑和图形绘制，使用 GDScript。
main.tscn：主场景。
project.godot：项目设置与启动入口。
tests.gd：自动化核心逻辑和地图可达性检查。

测试命令（在项目文件夹打开终端）：
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests.gd

图形无需下载素材。macOS 中文字体直接读取系统自带字体，没有复制或分发系统字体。

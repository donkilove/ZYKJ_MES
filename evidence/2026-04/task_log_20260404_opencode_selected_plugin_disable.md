# 任务留痕：关闭当前选中的 OpenCode 插件

## 1. 任务信息

- 任务名称：关闭当前选中的 OpenCode 插件
- 执行日期：2026-04-04
- 当前状态：已完成

## 2. 输入来源

- 用户指令：将我选中的这个插件先关掉
- 依据截图：当前插件页仅显示 1 个插件，路径为 `file:///C:/Users/Donki/.config/opencode/plugins/inject_via_fetch_patch.js`

## 3. 执行结论

1. 已将目标插件从自动加载目录移出，未做删除。
2. 插件文件已从 `C:\Users\Donki\.config\opencode\plugins\inject_via_fetch_patch.js` 移到 `C:\Users\Donki\.config\opencode\plugins_disabled\inject_via_fetch_patch.js.disabled`。
3. 通过 `C:\Users\Donki\AppData\Local\OpenCode\opencode-cli.exe debug config` 复核，当前 `plugin` 数组为空，说明插件已关闭。

## 4. 证据表

| 证据编号 | 来源 | 适用结论 |
| --- | --- | --- |
| E1 | `C:\Users\Donki\.config\opencode\plugins` 目录为空 | 目标插件已不在自动加载目录 |
| E2 | `C:\Users\Donki\.config\opencode\plugins_disabled\inject_via_fetch_patch.js.disabled` | 目标插件已被保留到禁用目录 |
| E3 | `C:\Users\Donki\AppData\Local\OpenCode\opencode-cli.exe debug config` 输出中的 `plugin = []` | OpenCode 当前已不加载任何插件 |

## 5. 假设与限制

- 假设截图中选中的插件就是当前唯一已加载插件。
- 本轮仅关闭插件，不修改 `opencode.json`、模型配置、上游地址或其他 MCP 配置。
- 若 OpenCode 当前进程已提前加载该插件，通常需要重启或新开会话后界面状态才会完全同步。

## 6. 恢复方式

1. 将 `C:\Users\Donki\.config\opencode\plugins_disabled\inject_via_fetch_patch.js.disabled` 移回 `C:\Users\Donki\.config\opencode\plugins\inject_via_fetch_patch.js`。
2. 重启 OpenCode 或新开会话。

# 指挥官执行留痕：CC Switch Codex 代理配置迁移到 OpenCode

日期：2026-04-04
更新时间：2026-04-04 19:40:00 +08:00

## 1. 任务信息

- 任务名称：参考 CC Switch 文档，将 Codex 侧代理/供应商配置接入 OpenCode
- 执行方式：指挥官模式
- 当前状态：进行中

## 2. 用户目标

- 先查看 `ccs / CC Switch` 文档或现有说明。
- 在可行前提下，由代理直接帮用户完成 OpenCode 侧配置。

## 3. 成功标准

1. 明确 CC Switch 中 Codex 与 OpenCode 的配置关系、导入方式与落点。
2. 若本机可写且配置结构清晰，则将 OpenCode 所需配置补齐到本机 CC Switch。
3. 通过独立验证确认：
   - OpenCode 配置记录存在；
   - 关键字段（接口地址、模型、鉴权、代理）已落盘；
   - 不破坏现有 Codex 配置。

## 4. 约束与假设

- 假设用户所说 `ccs` 即截图中的 `CC Switch`。
- 假设当前允许读取本机 CC Switch 安装目录与用户目录配置文件。
- 若官方文档无法获得，将以本机配置文件、数据库与已存日志作为补充证据。

## 5. Sequential Thinking 降级记录

- 触发时间：2026-04-04 19:40:00 +08:00
- 不可用工具：`Sequential Thinking`
- 降级原因：当前会话工具集中未提供该 MCP 调用入口。
- 替代方式：书面分解 + `update_plan` + 子 agent 闭环。
- 风险与补偿：无法保留原生思维链记录，改以任务日志、子 agent 摘要与验证留痕补偿。

## 6. 任务拆分

- A1 调研子任务：查找 CC Switch/CCS 文档、项目内留痕和本机配置结构，形成配置映射结论。
- A2 执行子任务：基于调研结果修改本机 CC Switch OpenCode 配置。
- A3 验证子任务：独立复核数据库/配置文件/UI 所需关键字段是否齐备。

## 7. 验收命令/检查项

- 读取本机 `CC Switch` 配置目录与数据库记录。
- 必要时对 `cc-switch.exe`、日志文件、`settings.json`、`cc-switch.db` 做只读检查。
- 验证 `providers`、`provider_endpoints`、`settings/common_config_opencode` 等可能落点。

## 8. 当前结论

- 2026-04-04 19:42 基线检查结果：
  - `C:\Users\Donki\.cc-switch\settings.json` 中 `visibleApps.opencode = true`，但不存在 `currentProviderOpencode`。
  - `C:\Users\Donki\.cc-switch\cc-switch.db` 的 `providers` 表当前仅有 1 条 `codex` 记录：
    - `id = mycodex-1775300645855`
    - `name = My Codex`
    - `website_url = https://yb.saigou.work:2083`
  - `provider_endpoints` 当前为空。
  - `settings.common_config_opencode` 已存在，内容为 OpenCode JSON 配置，`provider.openai.options.baseURL = https://yb.saigou.work:2053/v1`。
  - `proxy_config` 仅存在 `claude` / `codex` / `gemini` 三条，没有 `opencode`。
- 初步判断：OpenCode 页签为空的主因不是缺少 `common_config_opencode`，而是缺少 `providers(app_type='opencode')`、关联端点、当前供应商指针，以及可能缺少 `proxy_config(app_type='opencode')`。

## 9. 证据记录

- 证据#C1
  - 来源：`C:\Users\Donki\.cc-switch\settings.json`
  - 适用结论：OpenCode 页签已启用，但当前供应商指针缺失。
- 证据#C2
  - 来源：`C:\Users\Donki\.cc-switch\cc-switch.db` 结构化查询
  - 适用结论：当前只有 Codex 供应商卡片，OpenCode 供应商卡片与端点均缺失。
- 证据#C3
  - 来源：`C:\Users\Donki\.cc-switch\cc-switch.db` 结构化查询
  - 适用结论：`settings.common_config_opencode` 已存在，OpenCode 空白页并非因为通用配置为空。
- 证据#C4
  - 来源：`C:\Users\Donki\UserData\Code\ZYKJ_MES\evidence\task_log_20260404_cc_switch_opencode_config.md`
  - 适用结论：本机此前曾执行过一次 OpenCode 供应商补录，但当前状态已不再保留该记录，需以现状重新写入并复核。

## 10. 执行子 agent 输出摘要

- 执行子 agent：`Carson`
- 完成时间：2026-04-04 19:42 后
- 结果摘要：
  - 已创建本机备份：
    - `C:\Users\Donki\.cc-switch\backups\db_backup_20260404_194222_before_opencode_provider_repair.db`
    - `C:\Users\Donki\.cc-switch\backups\settings_backup_20260404_194222_before_opencode_provider_repair.json`
  - 已新增 OpenCode 供应商：
    - `id = myopencode-1775302943460`
    - `name = My OpenCode`
    - `website_url = https://yb.saigou.work:2053`
  - 已新增 OpenCode 端点：
    - `https://yb.saigou.work:2053/v1`
  - 已更新 `settings.json.currentProviderOpencode = myopencode-1775302943460`
  - 已重启 `cc-switch.exe`
- 已知未覆盖项：
  - 未复制 `proxy_config(app_type='codex')` 到 `opencode`
  - 子 agent 说明原因是当前 `proxy_config.app_type` 模式不接受 `opencode`

## 11. 独立验证结果

- 验证子 agent：`Gauss`
- 验证方式：只读复核 `C:\Users\Donki\.cc-switch\cc-switch.db`、`C:\Users\Donki\.cc-switch\settings.json`、备份目录与 `cc-switch.exe` 进程。
- 结论：通过
- 关键验证结果：
  - `providers` 中存在：
    - `id = mycodex-1775300645855, app_type = codex`
    - `id = myopencode-1775302943460, app_type = opencode`
  - `provider_endpoints` 中存在：
    - `provider_id = myopencode-1775302943460`
    - `url = https://yb.saigou.work:2053/v1`
  - `settings.json` 中存在：
    - `currentProviderCodex = mycodex-1775300645855`
    - `currentProviderOpencode = myopencode-1775302943460`
  - `settings` 表中仍存在：
    - `common_config_codex`
    - `common_config_opencode`
  - `proxy_config` 仅含 `claude/codex/gemini`，没有 `opencode`
  - `cc-switch.exe` 正在运行，启动时间为 `2026-04-04 19:42:23`
- 验证判断：
  - OpenCode 页签的供应商显示前置条件已满足。
  - `proxy_config` 缺少 `opencode` 不阻塞供应商卡片显示，但意味着当前版本无法按数据库现状为 OpenCode 单独持久化一条与 Codex 完全同构的独立代理记录。

## 12. 文档调研摘要

- 调研子 agent：`Erdos`
- 结论摘要：
  - `CC Switch v3.10.0` 发布说明明确支持 `OpenCode`。
  - `CC Switch v3.9.0` 发布说明明确支持本地代理、按应用接管与通用供应商。
  - 官方公开资料说明 `CC Switch` 配置落点采用 `~/.cc-switch/cc-switch.db` 与 `~/.cc-switch/settings.json`。
  - 文档未承诺自动导入 OpenCode 供应商；OpenCode 页签空白更合理的解释是其独立供应商记录缺失。
- 文档链接：
  - `https://docs.right.codes/docs/rc_cli_config/ccs`
  - `https://docs.right.codes/docs/rc_extension/opencode`
  - `https://github.com/farion1231/cc-switch`
  - `https://github.com/farion1231/cc-switch/releases`

## 13. 最终结论

- 已完成本机 `CC Switch` 的 OpenCode 供应商修复，当前数据库、设置文件和运行中进程状态一致。
- 无迁移，直接替换。

## 11. 文档子 agent 摘要

- 文档子 agent：`Erdos`
- 结论摘要：
  - `CC Switch v3.10.0` 已明确支持 `OpenCode`。
  - `CC Switch v3.9.0` 已支持 `Local API Proxy`、按应用接管与 `Universal Provider`。
  - 公开文档/README 明确配置目录采用 `~/.cc-switch/cc-switch.db + settings.json + backups/` 双层结构。
  - README 仅明确“首次启动自动导入 Claude/Codex 配置”，未承诺自动导入 `OpenCode`，因此 OpenCode 页签为空与当前现象一致。
- 参考链接：
  - https://docs.right.codes/docs/rc_cli_config/ccs
  - https://docs.right.codes/docs/rc_extension/opencode
  - https://github.com/farion1231/cc-switch
  - https://github.com/farion1231/cc-switch/releases

## 12. 独立验证结果

- 验证时间：2026-04-04 19:46:45 +08:00
- 验证方式：只读结构化回查（数据库、配置文件、备份文件、进程状态）
- 验证结论：通过
- 验证摘要：
  - `providers` 中存在 `app_type='opencode'` 记录：
    - `id = myopencode-1775302943460`
    - `name = My OpenCode`
    - `website_url = https://yb.saigou.work:2053`
  - `provider_endpoints` 中存在对应记录：
    - `provider_id = myopencode-1775302943460`
    - `url = https://yb.saigou.work:2053/v1`
  - `settings.json` 中：
    - `currentProviderCodex = mycodex-1775300645855`
    - `currentProviderOpencode = myopencode-1775302943460`
  - `settings.common_config_opencode` 仍存在，值非空。
  - `cc-switch.exe` 正在运行，启动时间 `2026-04-04 19:42:23 +08:00`，与执行子 agent 重启时间一致。
  - 备份文件存在：
    - `db_backup_20260404_194222_before_opencode_provider_repair.db`
    - `settings_backup_20260404_194222_before_opencode_provider_repair.json`
  - `proxy_config` 中不存在 `app_type='opencode'` 记录，但当前 UI 供应商列表展示所需的 `providers + provider_endpoints + currentProviderOpencode` 已齐备，因此不阻塞 OpenCode 页签显示供应商；其影响仅限于无法为 OpenCode 单独复制一条与 Codex 同构的应用级代理记录。

## 13. 最终结论

- 已按当前 CC Switch 能力把 OpenCode 页签补齐到可见、可选供应商状态。
- Codex 当前供应商未被覆盖，OpenCode 已有独立供应商和端点。
- 无迁移脚本，直接替换。

## 10. 执行记录

- 2026-04-04 19:42:22 +08:00
  - 停止运行中的 `CC Switch` 进程，避免 SQLite 占用与缓存回写覆盖。
  - 生成备份：
    - `C:\Users\Donki\.cc-switch\backups\db_backup_20260404_194222_before_opencode_provider_repair.db`
    - `C:\Users\Donki\.cc-switch\backups\settings_backup_20260404_194222_before_opencode_provider_repair.json`
- 2026-04-04 19:42:23 +08:00
  - 基于 `settings.common_config_opencode` 补写 `providers(app_type='opencode')`：
    - `id = myopencode-1775302943460`
    - `name = My OpenCode`
    - `website_url = https://yb.saigou.work:2053`
    - `settings_config = settings.common_config_opencode`
  - 补写 `provider_endpoints`：
    - `provider_id = myopencode-1775302943460`
    - `app_type = opencode`
    - `url = https://yb.saigou.work:2053/v1`
  - 更新 `C:\Users\Donki\.cc-switch\settings.json`：
    - `currentProviderOpencode = myopencode-1775302943460`
  - 重新启动 `CC Switch`。
- 2026-04-04 19:42:20 +08:00 至 19:42:21 +08:00
  - 尝试补写 `proxy_config(app_type='opencode')` 失败，数据库返回约束错误：
    - `CHECK constraint failed: app_type IN ('claude','codex','gemini')`
  - 结论：当前安装版本数据库层未开放 `opencode` 的独立代理配置行，不能像 `codex` 一样直接复制该表记录。

## 11. 验证记录

- 2026-04-04 19:43:10 +08:00 只读回查结果：
  - `providers` 表已存在 `opencode` 供应商：
    - `id = myopencode-1775302943460`
    - `name = My OpenCode`
    - `website_url = https://yb.saigou.work:2053`
  - `provider_endpoints` 表已存在 `opencode` 端点：
    - `url = https://yb.saigou.work:2053/v1`
  - `settings.common_config_opencode` 仍保留，长度 `2219`，说明通用配置未被清空。
  - `settings.json` 已包含 `currentProviderOpencode = myopencode-1775302943460`。
  - `cc-switch.exe` 已重新启动，当前进程存在。
- 验证结论：
  - OpenCode 页签所需的供应商卡片、端点和当前指针已补齐。
  - Codex 现有供应商配置未被覆盖。
  - 独立代理配置未复制成功，原因是当前数据库模式不支持 `opencode` 写入 `proxy_config`。

## 12. 最终结论

- 本次已完成 OpenCode 页签可见供应商的配置修复。
- 未完成项仅剩“将 Codex 独立代理表复制到 OpenCode”，该项受当前 `CC Switch` 数据库约束限制，不是写入步骤遗漏。
- 迁移说明：无迁移，直接补录并替换当前指针。

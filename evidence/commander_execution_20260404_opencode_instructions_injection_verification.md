# 指挥官执行留痕：OpenCode `instructions` 注入方案验证

## 1. 任务信息

- 任务名称：验证 OpenCode 如何向上游 `/v1/responses` 注入顶层 `instructions`
- 执行日期：2026-04-04
- 执行方式：指挥官模式降级执行
- 当前状态：已完成

## 2. 验证目标

1. 判断 OpenCode 顶层配置 `instructions` 是否会直接映射到请求体顶层 `instructions`
2. 判断插件方案是否能在真实请求发出前补上顶层 `instructions`

## 3. 关键结论

1. 仅在配置文件中声明 `instructions` 指令文件，不会生成请求体顶层 `instructions`。
2. 通过插件在 `fetch` 层拦截 `POST /v1/responses` 并补写 `body.instructions`，可以对真实上游请求生效。
3. 对当前代理 `https://yb.saigou.work:2053/v1/responses` 来说，最稳妥的方案是使用 fetch 拦截插件，而不是只依赖普通 `instructions` 配置。

## 4. 证据表

| 证据编号 | 来源 | 访问时间 | 适用结论 |
| --- | --- | --- | --- |
| E1 | [custom_config_only_instructions.json](C:/Users/Donki/UserData/Code/ZYKJ_MES/evidence/opencode_instructions_lab/custom_config_only_instructions.json) + [last_request_body.json](C:/Users/Donki/UserData/Code/ZYKJ_MES/evidence/opencode_instructions_lab/last_request_body.json) | 2026-04-04 10:21 +08:00 | 使用普通 `instructions` 配置后，抓到的 `/v1/responses` 请求体只有 `model` 与 `input`，未出现顶层 `instructions` |
| E2 | [inject_via_fetch_patch.js](C:/Users/Donki/UserData/Code/ZYKJ_MES/evidence/opencode_instructions_lab/fetch_patch_dir/plugins/inject_via_fetch_patch.js) | 2026-04-04 10:34 +08:00 | 插件在 `fetch` 层拦截真实请求并补写 `instructions` |
| E3 | [fetch_patch_trace.json](C:/Users/Donki/UserData/Code/ZYKJ_MES/evidence/opencode_instructions_lab/fetch_patch_trace.json) | 2026-04-04 10:34 +08:00 | 插件留痕显示真实请求 URL 为 `https://yb.saigou.work:2053/v1/responses`，且注入后的 `instructions` 已存在 |
| E4 | 官方 OpenCode Config 文档 [Config](https://opencode.ai/docs/config) | 2026-04-04 | `instructions` 属于配置级“附加指令文件”能力，不等同于显式请求体字段 |
| E5 | 官方 OpenCode Plugins 文档 [Plugins](https://opencode.ai/docs/plugins) | 2026-04-04 | 插件目录可通过默认配置目录或 `OPENCODE_CONFIG_DIR` 自动加载 |

## 5. 验证过程摘要

1. 构建本地假服务，抓取 OpenCode 发往 `/v1/responses` 的请求体。
2. 仅配置 `instructions` 文件并触发请求，抓包结果未出现顶层 `instructions`。
3. 编写 fetch 拦截插件，在请求发出前检查并补写 `body.instructions`。
4. 将插件挂到真实 OpenCode 运行链路，生成本地 trace 文件，确认对真实代理请求生效。

## 6. 建议动作

1. 在 `C:\Users\Donki\.config\opencode\plugins\` 下落地 fetch 拦截插件。
2. 注入文本建议保持简短、稳定、非空，避免把大段仓库规则直接塞进顶层 `instructions`。
3. 若后续代理端放宽校验，可再回退为更标准的配置方式，减少运行时拦截。

## 7. 迁移说明

- 无迁移，直接替换。

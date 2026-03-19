---
name: mes-local-dev-bootstrap
description: 处理 ZYKJ_MES 本地开发启动、NO_PROXY、health 检查、bootstrap admin 与前后端联调链路。
---

# mes-local-dev-bootstrap

## 何时使用

- 用户明确要求启动本地前后端、排查启动失败或做联调验证。
- 需要检查 `NO_PROXY`、`MES_API_BASE_URL`、health 检查、管理员引导等启动链路。
- 需要判断是脚本问题、代理问题、后端未就绪还是前端基址配置问题。

## 不适用场景

- 仅修改代码，不需要实际拉起服务。
- 仅写迁移脚本或测试，不需要联调。
- 未经用户要求，不要把本技能当成默认“顺手启动一下”的动作。

## 本仓库关键路径

- `start_backend.py`
- `start_frontend.py`
- `backend/README.md`
- `backend/app/bootstrap/startup_bootstrap.py`
- `backend/app/main.py`
- `frontend/lib/main.dart`
- `frontend/lib/pages/login_page.dart`

## 默认原则

- 优先阅读启动脚本与参数，再决定是否执行，不要凭经验直接手敲命令。
- 明确提醒用户：后端启动会触发 bootstrap，可能建库、跑迁移、seed；前端启动默认会尝试 bootstrap admin。
- 除非用户明确要求执行启动，否则本技能默认用于“检查与规划”，不是“自动拉起服务”。

## 执行步骤

1. 先核对用户目标是“阅读排查”还是“实际启动”。
2. 阅读 `start_backend.py`、`start_frontend.py` 和 `backend/README.md`，确认默认参数与副作用。
3. 如需执行，优先使用仓库脚本而不是手写命令，以保留 `NO_PROXY` 合并与启动前检查。
4. 遇到本地代理环境时，优先检查 `NO_PROXY` 是否覆盖 `localhost`、`127.0.0.1`、`::1`。
5. 排查前端连不上后端时，先看 `/health`、`MES_API_BASE_URL`、登录页默认基址与启动参数。
6. 若只需启动前端但不希望触发管理员引导，使用 `--skip-bootstrap-admin`。
7. 若只需快速验证已安装依赖，可按需使用 `--skip-pub-get` 减少无关开销。

## 验证与证据

- 记录实际执行的启动命令与参数。
- 记录后端 health、前端目标基址、是否触发 bootstrap admin。
- 若因为副作用风险而未执行启动，要明确说明这是保护性决策。

## 输出要求

- 明确说明本次是“只读排查”还是“实际启动”。
- 明确说明是否触发了建库、迁移、seed 或管理员引导。
- 明确说明失败点在脚本、环境变量、网络代理、后端服务还是前端配置。

## 风险提示

- `start_backend.py` 与应用启动不是纯读操作，会触发数据库层副作用。
- `start_frontend.py` 默认会在本地后端就绪后调用 bootstrap admin 接口，不能无提示地执行。

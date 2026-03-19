---
name: mes-rbac-page-visibility
description: 处理 ZYKJ_MES 仓库中的角色、能力码、页面目录、侧边栏与 Tab 可见性联动变更。
---

# mes-rbac-page-visibility

## 何时使用

- 需要新增、拆分或收敛能力码。
- 需要修改模块、页面、Tab 的可见性规则。
- 需要排查“有权限但页面不显示”或“页面显示但无操作权限”的问题。
- 需要修复消息跳转目标页、目标 Tab 与权限快照不一致的问题。

## 不适用场景

- 仅改登录鉴权算法或 JWT 参数。
- 仅改页面样式，不涉及权限控制。
- 仅做数据导入导出，与页面目录无关。

## 本仓库关键路径

- `backend/app/core/authz_catalog.py`
- `backend/app/core/authz_hierarchy_catalog.py`
- `backend/app/core/page_catalog.py`
- `backend/app/services/authz_service.py`
- `backend/app/api/deps.py`
- `backend/app/api/v1/endpoints/authz.py`
- `frontend/lib/models/authz_models.dart`
- `frontend/lib/services/authz_service.dart`
- `frontend/lib/services/page_catalog_service.dart`
- `frontend/lib/pages/main_shell_page.dart`

## 默认原则

- 页面可见性、能力码、目录 code 必须保持单一映射关系，避免前后端各自硬编码一份不同字典。
- 先梳理目录与能力关系，再改页面显示，不要只在前端隐藏按钮当作权限修复。
- 未经用户明确要求，不直接调用会写入权限配置的数据接口。

## 执行步骤

1. 明确本次变更落在哪一层：角色、能力码、侧边栏页面、子 Tab、消息跳转还是权限快照。
2. 核对后端权限目录：`authz_catalog`、`authz_hierarchy_catalog`、`page_catalog`。
3. 核对后端快照与校验逻辑：`authz_service.py`、`api/deps.py`、相关接口。
4. 更新前端模型与服务，确保权限快照、页面目录和菜单渲染使用同一组 code。
5. 检查 `frontend/lib/pages/main_shell_page.dart` 中的菜单、Tab 过滤与兜底逻辑。
6. 如涉及消息跳转，校验目标 `pageCode`、`tabCode` 与当前账号可见范围是否一致。
7. 明确系统管理员等保底规则，避免因为收敛权限而误伤基础访问入口。

## 验证与证据

- 至少验证 401、403、无可访问页面、兜底目录四类路径。
- 如修改了前端菜单或页面显示，至少跑相关 widget test 或补充针对性用例。
- 若未做真实账号联调，必须说明仅完成静态检查或模拟测试。

## 输出要求

- 明确列出修改的能力码、页面 code、Tab code 与受影响模块。
- 明确说明是“可见性修复”“能力拆分”还是“权限保底修复”。
- 明确指出是否存在需要人工复核的账号或角色配置。

## 风险提示

- 这个仓库的权限问题常常不是单点问题，而是目录、快照、菜单、页面内按钮四层不同步。
- 系统管理员保底能力和页面可见性入口不能误删，否则会导致整模块无法自助恢复。

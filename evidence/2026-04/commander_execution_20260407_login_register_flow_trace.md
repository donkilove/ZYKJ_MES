# 指挥官任务日志

## 1. 任务信息

- 任务名称：登录页“登录 / 去注册”按钮全流程梳理
- 执行日期：2026-04-07
- 执行方式：代码链路盘点 + 前后端接口追踪 + 测试证据核对
- 当前状态：已完成
- 指挥模式：主 agent 拆解汇总，子 agent 辅助只读调研，主 agent 统一收口

## 2. 输入来源

- 用户指令：整理“这个页面”的登录和注册按钮全流程，要覆盖完整主链路与分支。
- 当前判定页面：
  - `frontend/lib/pages/login_page.dart`
- 判定依据：
  - 该页面同时存在“登录”与“去注册”按钮，并承接注册回流提示。

## 3. Sequential Thinking 留痕

- 执行时间：2026-04-07
- 结论摘要：
  1. 需先确认“这个页面”具体是哪一页，避免错把个人中心等页面当作目标。
  2. 登录与注册要分别追到前端事件、服务接口、后端状态变更、审批/驳回、消息回流和最终重新登录闭环。
  3. 除源码外，还需引用前后端测试作为流程分支的佐证。

## 4. 结论摘要

1. 目标页面是登录页 `login_page.dart`，其中“登录”按钮走 `/auth/login`，成功后进入 `AppBootstrapPage` 的登录成功分支，再根据 `must_change_password` 决定是先跳强制改密页还是直接进主壳。
2. “去注册”按钮会打开 `register_page.dart`，提交注册申请后不会自动登录，而是返回登录页并回填接口地址与账号，同时提示“等待审批后再登录”。
3. 后端注册申请先写入 `sys_registration_request`，状态为 `pending`，并向系统管理员发待办消息，目标页签为 `registration_approval`。
4. 审批通过后才真正创建用户账号，且新账号默认 `must_change_password=True`；系统再向申请人发通知，目标页签为 `account_settings`，路由载荷为 `{"action": "change_password"}`。
5. 驳回只会把申请单状态改为 `rejected` 并记录原因，不会创建用户；申请人若还想进入系统，只能重新走注册申请，再回到登录流程。

## 5. 证据记录

- E01
  - 来源：[login_page.dart](C:/Users/Donki/UserData/Code/ZYKJ_MES/frontend/lib/pages/login_page.dart#L133)
  - 适用结论：登录按钮点击入口在 `_submitLogin()`。

- E02
  - 来源：[login_page.dart](C:/Users/Donki/UserData/Code/ZYKJ_MES/frontend/lib/pages/login_page.dart#L192)
  - 适用结论：“去注册”按钮点击后进入 `RegisterPage`，返回时会回填账号与接口地址。

- E03
  - 来源：[auth_service.dart](C:/Users/Donki/UserData/Code/ZYKJ_MES/frontend/lib/services/auth_service.dart#L9)
  - 适用结论：前端登录调用 `/auth/login`，返回 `token + mustChangePassword`。

- E04
  - 来源：[auth_service.dart](C:/Users/Donki/UserData/Code/ZYKJ_MES/frontend/lib/services/auth_service.dart#L38)
  - 适用结论：前端注册调用 `/auth/register`。

- E05
  - 来源：[auth.py](C:/Users/Donki/UserData/Code/ZYKJ_MES/backend/app/api/v1/endpoints/auth.py#L68)
  - 适用结论：后端登录会区分账号不存在、待审批、停用/已删、密码错误、成功登录等分支。

- E06
  - 来源：[auth.py](C:/Users/Donki/UserData/Code/ZYKJ_MES/backend/app/api/v1/endpoints/auth.py#L200)
  - 适用结论：后端注册成功后返回 `pending_approval`，并给管理员发注册审批待办消息。

- E07
  - 来源：[registration_approval_page.dart](C:/Users/Donki/UserData/Code/ZYKJ_MES/frontend/lib/pages/registration_approval_page.dart#L404)
  - 适用结论：注册审批页包含通过/驳回两条处理路径。

- E08
  - 来源：[auth.py](C:/Users/Donki/UserData/Code/ZYKJ_MES/backend/app/api/v1/endpoints/auth.py#L337)
  - 适用结论：审批通过后创建真实用户账号，并给申请人发“去个人中心改密码”的通知。

- E09
  - 来源：[main.dart](C:/Users/Donki/UserData/Code/ZYKJ_MES/frontend/lib/main.dart#L138)
  - 适用结论：登录成功后若 `mustChangePassword=true`，前端先进入 `ForceChangePasswordPage`。

- E10
  - 来源：[test_user_module_integration.py](C:/Users/Donki/UserData/Code/ZYKJ_MES/backend/tests/test_user_module_integration.py#L1298)
  - 适用结论：后端集成测试覆盖注册成功、待审批冲突、密码规则冲突、账号已存在冲突。

- E11
  - 来源：[test_user_module_integration.py](C:/Users/Donki/UserData/Code/ZYKJ_MES/backend/tests/test_user_module_integration.py#L1117)
  - 适用结论：后端集成测试覆盖登录对“待审批 / 停用 / 已删除 / 不存在”账号的分支处理。

- E12
  - 来源：[test_message_module_integration.py](C:/Users/Donki/UserData/Code/ZYKJ_MES/backend/tests/test_message_module_integration.py#L736)
  - 适用结论：审批通过通知会跳到 `account_settings` 页签并携带 `change_password` 路由载荷。

## 6. 子 agent 摘要

- 子 agent：`Pasteur`
- 类型：只读调研
- 责任：辅助梳理注册按钮/注册申请链路
- 留痕方式：若子 agent 受限未直接写入 evidence，则由主 agent 代记。

## 7. 最终结论

- 登录按钮和去注册按钮都位于登录页，但它们不是并行等价入口。
- “登录”是直接认证入口；“去注册”只是创建待审批申请单的入口，不会直接生成可登录账号。
- 用户真正回到登录闭环要么经过审批通过后重新在登录页登录，要么首次登录后被强制引导到改密页，再清空会话重新登录。
- 额外观察：前端虽存在 `SessionStore`，但登录成功后未调用 `save()`，且应用启动时固定 `clear()`；当前登录态是内存态，不是持久化登录态。

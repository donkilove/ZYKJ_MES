# MES API 规划（v1）

## 1. 基础约定

- Base URL：`/api/v1`
- 认证方式：`Authorization: Bearer <token>`
- 统一响应结构：

```json
{
  "code": 0,
  "message": "ok",
  "data": {}
}
```

## 2. 认证接口（Sprint 1 已实现）

- `POST /auth/login`：登录
- `POST /auth/register`：注册账号（用户名与姓名使用同一账号字段）
- `GET /auth/me`：当前登录用户信息（含角色、工序、权限）

## 3. 角色与权限（Sprint 1 已实现）

### 3.1 固定角色

- `system_admin`：系统管理员角色
- `production_admin`：生产管理员角色
- `quality_admin`：品质管理员角色
- `operator`：操作员角色

### 3.2 角色接口

- `GET /roles`：角色分页查询
- `GET /roles/{id}`：角色详情查询

### 3.3 权限接口

- `GET /permissions`：权限列表查询

## 4. 工序接口（Sprint 1 已实现）

- `GET /processes`：工序分页查询
- `POST /processes`：创建工序
- `PUT /processes/{id}`：更新工序名称

默认工序（初始化脚本自动创建）：

- `laser_marking`：激光打标
- `product_testing`：产品测试
- `product_assembly`：产品组装
- `product_packaging`：产品包装

## 5. 用户接口（Sprint 1 已实现）

- `GET /users`：用户分页查询
- `POST /users`：创建用户
- `GET /users/{id}`：用户详情查询
- `PUT /users/{id}`：更新用户
- `DELETE /users/{id}`：删除用户

说明：

- 账号不再支持“禁用/启用”接口（已移除 `PATCH /users/{id}/status`）。
- 每个用户必须至少分配一个角色。
- 当角色包含 `operator` 时，必须分配至少一个工序。
- 非 `operator` 角色不允许分配工序。

## 6. 后续计划接口（Sprint 2+）

- 产品管理：`/products`
- 产品参数管理：`/product-param-templates`、`/product-param-items`
- 生产订单管理：`/production-orders`
- 首件管理：`/first-articles`
- 综合查询：`/queries/*`

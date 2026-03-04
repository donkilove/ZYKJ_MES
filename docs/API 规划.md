# MES API 接口规划

## 1. API 设计规范

### 1.1 基础约定

- 基础路径：`/api/v1`
- 认证方式：JWT Bearer Token
- 请求/响应格式：JSON
- 统一响应格式：
  ```json
  {
    "code": 0,
    "message": "success",
    "data": {}
  }
  ```

### 1.2 错误码规范

- `0`：成功
- `400`：请求参数错误
- `401`：未认证或 Token 过期
- `403`：权限不足
- `404`：资源不存在
- `500`：服务器内部错误

## 2. 认证接口（Auth）

### 2.1 用户登录

```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "Admin@123456"
}
```

响应：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "token_type": "Bearer"
  }
}
```

### 2.2 获取当前用户信息

```http
GET /api/v1/auth/me
Authorization: Bearer {token}
```

响应：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 1,
    "username": "admin",
    "full_name": "system admin",
    "roles": ["system_admin"],
    "processes": []
  }
}
```

## 3. 用户管理接口（Users）

### 3.1 获取用户列表

```http
GET /api/v1/users?page=1&page_size=50&keyword=admin
Authorization: Bearer {token}
```

响应：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "total": 10,
    "items": [
      {
        "id": 1,
        "username": "admin",
        "full_name": "system admin",
        "roles": ["system_admin"],
        "processes": [],
        "created_at": "2026-02-25T10:00:00",
        "updated_at": "2026-02-25T10:00:00"
      }
    ]
  }
}
```

### 3.2 创建用户

```http
POST /api/v1/users
Authorization: Bearer {token}
Content-Type: application/json

{
  "username": "operator1",
  "full_name": "操作员 1",
  "password": "Password@123",
  "role_ids": [4],
  "process_ids": [1, 2]
}
```

### 3.3 获取用户详情

```http
GET /api/v1/users/{user_id}
Authorization: Bearer {token}
```

### 3.4 更新用户

```http
PUT /api/v1/users/{user_id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "full_name": "操作员 1（更新）",
  "password": "NewPassword@456",
  "role_ids": [4],
  "process_ids": [1]
}
```

### 3.5 删除用户

```http
DELETE /api/v1/users/{user_id}
Authorization: Bearer {token}
```

## 4. 角色管理接口（Roles）

### 4.1 获取角色列表

```http
GET /api/v1/roles
Authorization: Bearer {token}
```

响应：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "items": [
      {
        "id": 1,
        "code": "system_admin",
        "name": "系统管理员角色"
      },
      {
        "id": 2,
        "code": "production_admin",
        "name": "生产管理员角色"
      },
      {
        "id": 3,
        "code": "quality_admin",
        "name": "品质管理员角色"
      },
      {
        "id": 4,
        "code": "operator",
        "name": "操作员角色"
      }
    ]
  }
}
```

## 5. 工序管理接口（Processes）

### 5.1 获取工序列表

```http
GET /api/v1/processes
Authorization: Bearer {token}
```

响应：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "items": [
      {
        "id": 1,
        "code": "laser_marking",
        "name": "激光打标"
      },
      {
        "id": 2,
        "code": "product_testing",
        "name": "产品测试"
      },
      {
        "id": 3,
        "code": "product_assembly",
        "name": "产品组装"
      },
      {
        "id": 4,
        "code": "product_packaging",
        "name": "产品包装"
      }
    ]
  }
}
```

### 5.2 创建工序

```http
POST /api/v1/processes
Authorization: Bearer {token}
Content-Type: application/json

{
  "code": "new_process",
  "name": "新工序"
}
```

### 5.3 更新工序

```http
PUT /api/v1/processes/{process_id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "新工序（更新）"
}
```

## 6. 产品管理接口（Products）

### 6.1 获取产品列表

```http
GET /api/v1/products?page=1&page_size=50&keyword=产品 A
Authorization: Bearer {token}
```

响应：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "total": 10,
    "items": [
      {
        "id": 1,
        "name": "产品 A",
        "last_parameter_summary": {
          "total_changed_keys": 3,
          "latest_changed_keys": ["参数 1", "参数 2"]
        },
        "created_at": "2026-02-25T10:00:00",
        "updated_at": "2026-02-25T10:00:00"
      }
    ]
  }
}
```

### 6.2 创建产品

```http
POST /api/v1/products
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "产品 A"
}
```

### 6.3 删除产品

```http
POST /api/v1/products/{product_id}/delete
Authorization: Bearer {token}
Content-Type: application/json

{
  "password": "Admin@123456"
}
```

### 6.4 获取产品参数

```http
GET /api/v1/products/{product_id}/parameters
Authorization: Bearer {token}
```

响应：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "product_id": 1,
    "product_name": "产品 A",
    "total": 5,
    "items": [
      {
        "name": "参数 1",
        "category": "电气参数",
        "type": "Text",
        "value": "220V",
        "sort_order": 1,
        "is_preset": true
      }
    ]
  }
}
```

### 6.5 更新产品参数

```http
PUT /api/v1/products/{product_id}/parameters
Authorization: Bearer {token}
Content-Type: application/json

{
  "remark": "批量更新参数",
  "items": [
    {
      "name": "参数 1",
      "category": "电气参数",
      "type": "Text",
      "value": "220V"
    }
  ]
}
```

### 6.6 获取产品参数历史

```http
GET /api/v1/products/{product_id}/parameter-history?page=1&page_size=20
Authorization: Bearer {token}
```

响应：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "total": 5,
    "items": [
      {
        "id": 1,
        "remark": "批量更新参数",
        "changed_keys": ["参数 1", "参数 2"],
        "operator_username": "admin",
        "created_at": "2026-02-25T10:00:00"
      }
    ]
  }
}
```

## 7. 设备管理接口（Equipment）

### 7.1 获取设备列表

```http
GET /api/v1/equipment?page=1&page_size=50&keyword=设备 A
Authorization: Bearer {token}
```

### 7.2 创建设备

```http
POST /api/v1/equipment
Authorization: Bearer {token}
Content-Type: application/json

{
  "code": "EQ001",
  "name": "设备 A",
  "model": "型号 X",
  "location": "车间 1",
  "owner_name": "张三"
}
```

### 7.3 更新设备

```http
PUT /api/v1/equipment/{equipment_id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "设备 A（更新）",
  "is_enabled": false
}
```

### 7.4 删除设备

```http
DELETE /api/v1/equipment/{equipment_id}
Authorization: Bearer {token}
```

## 8. 页面可见性接口（UI）

### 8.1 获取页面可见性配置

```http
GET /api/v1/ui/page-visibility
Authorization: Bearer {token}
```

### 8.2 更新页面可见性配置

```http
PUT /api/v1/ui/page-visibility
Authorization: Bearer {token}
Content-Type: application/json

{
  "role_id": 1,
  "visible_pages": ["user_management", "product_management"]
}
```

## 9. 权限控制矩阵

| 接口 | system_admin | production_admin | quality_admin | operator |
| --- | --- | --- | --- | --- |
| Auth | ✓ | ✓ | ✓ | ✓ |
| Users | ✓ | - | - | - |
| Roles | ✓ | - | - | - |
| Processes | ✓ | - | - | - |
| Products (读) | ✓ | ✓ | ✓ | ✓ |
| Products (写) | ✓ | ✓ | - | - |
| Equipment (读) | ✓ | ✓ | ✓ | ✓ |
| Equipment (写) | ✓ | ✓ | - | - |
| UI 配置 | ✓ | - | - | - |

## 10. 接口文档地址

- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`
- OpenAPI JSON: `http://127.0.0.1:8000/openapi.json`

## 11. 工艺模块 V1（工段 + 小工序 + 产品多模板）

### 11.1 新增工艺接口

```http
GET    /api/v1/craft/stages
POST   /api/v1/craft/stages
PUT    /api/v1/craft/stages/{stage_id}
DELETE /api/v1/craft/stages/{stage_id}

GET    /api/v1/craft/processes
POST   /api/v1/craft/processes
PUT    /api/v1/craft/processes/{process_id}
DELETE /api/v1/craft/processes/{process_id}

GET    /api/v1/craft/templates
POST   /api/v1/craft/templates
GET    /api/v1/craft/templates/{template_id}
PUT    /api/v1/craft/templates/{template_id}
DELETE /api/v1/craft/templates/{template_id}
```

权限：

- `system_admin`、`production_admin`：可读写
- `quality_admin`、`operator`：无权限（403）

### 11.2 生产订单接口升级

`POST /api/v1/production/orders` 与 `PUT /api/v1/production/orders/{order_id}` 新增入参：

- `template_id`
- `process_steps`（步骤内含 `step_order/stage_id/process_id`）
- `save_as_template`
- `new_template_name`
- `new_template_set_default`

兼容说明：

- `process_codes` 仍保留一个版本周期，避免旧前端立即中断。

### 11.3 模板同步未完成订单

更新模板（`PUT /api/v1/craft/templates/{template_id}`）时可带 `sync_orders=true`：

- `pending` 订单：重建全流程
- `in_progress` 订单：仅重建当前工序之后

冲突返回：

- 状态码 `409`
- 响应 detail 含 `sync_result.total/synced/skipped/reasons`

### 11.4 过程/保养口径调整

- `GET /api/v1/processes` 语义调整为“小工序列表 + 工段信息”。
- 保养域 `execution_process_code` 语义调整为“工段 code”。

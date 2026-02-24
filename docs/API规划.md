# MES API 规划（v1 草案）

## 1. 基础约定

- Base URL：`/api/v1`
- 认证方式：`Authorization: Bearer <token>`
- 响应结构：

```json
{
  "code": 0,
  "message": "ok",
  "data": {}
}
```

## 2. 认证与用户

- `POST /auth/login`：登录
- `POST /auth/refresh`：刷新 token
- `GET /users`：用户列表查询
- `POST /users`：创建用户
- `GET /users/{id}`：用户详情
- `PUT /users/{id}`：更新用户
- `PATCH /users/{id}/status`：启停用户
- `GET /roles`：角色列表
- `POST /roles`：创建角色

## 3. 产品管理

- `GET /products`：产品分页查询
- `POST /products`：新增产品
- `GET /products/{id}`：产品详情
- `PUT /products/{id}`：更新产品
- `PATCH /products/{id}/status`：启停产品

## 4. 产品参数管理

- `GET /product-param-templates`：模板列表
- `POST /product-param-templates`：新增模板
- `GET /product-param-templates/{id}`：模板详情
- `PUT /product-param-templates/{id}`：更新模板
- `GET /product-param-items`：参数项列表
- `POST /product-param-items`：新增参数项
- `PUT /product-param-items/{id}`：更新参数项
- `GET /products/{id}/params`：产品参数值查询
- `PUT /products/{id}/params`：批量更新产品参数值

## 5. 生产订单管理

- `GET /production-orders`：订单分页查询
- `POST /production-orders`：创建订单
- `GET /production-orders/{id}`：订单详情
- `PUT /production-orders/{id}`：更新订单
- `POST /production-orders/{id}/release`：下发订单
- `POST /production-orders/{id}/start`：开始生产
- `POST /production-orders/{id}/complete`：完成订单
- `POST /production-orders/{id}/close`：关闭订单

## 6. 首件管理

- `GET /first-articles`：首件分页查询
- `POST /first-articles`：提交首件
- `GET /first-articles/{id}`：首件详情
- `POST /first-articles/{id}/approve`：审核通过
- `POST /first-articles/{id}/reject`：审核驳回
- `GET /first-articles/{id}/logs`：首件审核日志

## 7. 查询接口建议

- `GET /queries/products`：产品综合查询（支持编码、名称、状态）。
- `GET /queries/production-orders`：订单综合查询（支持订单号、产品、状态、时间区间）。
- `GET /queries/first-articles`：首件综合查询（支持订单号、结果、审核人、时间区间）。

## 8. 错误码建议

- `0`：成功
- `1001`：参数校验失败
- `1002`：认证失败
- `1003`：权限不足
- `2001`：资源不存在
- `2002`：状态流转非法
- `3001`：数据库异常
- `9999`：系统未知错误

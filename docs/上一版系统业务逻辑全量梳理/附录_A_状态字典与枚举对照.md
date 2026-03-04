# 附录_A_状态字典与枚举对照

## A1. 订单与工序状态
| 字段 | 枚举值 | 语义 | 主要使用位置 |
|---|---|---|---|
| `orders.status` | `待生产` | 订单已建但未实际生产 | 建单后初始化 |
| `orders.status` | `生产中` | 订单存在进行中工序或在制数量 | 开工后 |
| `orders.status` | `生产完成` | 订单达到完工条件 | 全工序完成后 |
| `order_processes.status` | `待生产` | 工序尚未进入执行 | 初始化/流转前 |
| `order_processes.status` | `进行中` | 当前工序正在生产 | 首件通过后开工 |
| `order_processes.status` | `生产中` | 工序已结束一轮但可再次首件/继续生产 | 部分完成场景 |
| `order_processes.status` | `生产完成` | 工序完成 | 工序达标后 |
| `process_status.status` | `待生产/进行中/生产中/生产完成` | 工序统计状态，与 `order_processes` 联动 | 报工累计与可见量计算 |

## A2. 子订单与授权状态
| 字段 | 枚举值 | 语义 |
|---|---|---|
| `order_sub_orders.status` | `待生产` | 子订单待处理 |
| `order_sub_orders.status` | `生产中` | 子订单当前用户执行中 |
| `order_sub_orders.status` | `已完成` | 子订单本轮已完成，可隐藏待下轮恢复 |
| `assist_authorizations.status` | `待审批` | 代班申请创建后待管理员审批 |
| `assist_authorizations.status` | `已批准` | 审批通过，代班生效 |
| `assist_authorizations.status` | `已拒绝` | 审批拒绝 |
| `assist_authorizations.status` | `已完成` | 代班一次生产完成后自动失效 |

## A3. 首件与维修状态
| 字段 | 枚举值 | 语义 |
|---|---|---|
| `first_article_records.result` | `合格` | 允许工序放行进入生产 |
| `first_article_records.result` | `不合格` | 不放行，需要重检 |
| `repair_orders.status` | `维修中` | 维修单创建后待处理 |
| `repair_orders.status` | `维修完成` | 维修完成并已结单 |

## A4. 用户与会话状态
| 字段 | 枚举值 | 语义 |
|---|---|---|
| `user_status.status` | `在线` | 心跳在有效窗口内 |
| `user_status.status` | `离线` | 退出或心跳超时 |
| `register_requests.status` | `待处理` | 注册申请待管理员审批 |

## A5. 页面代码字典（visibility）
| 页面 code | 中文页面 |
|---|---|
| `user_management` | 用户管理 |
| `product_management` | 产品管理 |
| `product_parameter_management` | 产品参数管理 |
| `product_parameter_query` | 产品参数查询 |
| `production_order_management` | 生产订单管理 |
| `production_order_query` | 生产订单查询 |
| `production_data_query` | 生产数据查询 |
| `quality_data_query` | 品质数据查询 |
| `repair_order_query` | 维修订单查询 |
| `first_article_management` | 首件管理 |
| `message_center` | 消息中心 |
| `plugin_tool_page` | 插件工具 |

## A6. 角色与默认页面可见性（来自 visibility_config.json）
| 角色 | 默认可见页面概述 |
|---|---|
| 系统管理员 | 全部页面可见 |
| 生产管理员 | 订单管理/查询、生产数据、消息、插件、参数查询 |
| 品质管理员 | 品质查询、首件管理、消息、插件、参数查询 |
| 维修 | 维修查询、消息、插件、参数查询 |
| 激光打标操作员 | 订单查询、消息、插件、参数查询 |
| 产品测试操作员 | 订单查询、消息、插件、参数查询 |
| 产品组装操作员 | 订单查询、消息、插件、参数查询 |
| 产品包装操作员 | 订单查询、消息、插件、参数查询 |

## A7. 工序到角色映射（生产/消息常用）
| 工序 | 角色（主映射） | 兼容说明 |
|---|---|---|
| 激光打标 | 激光打标操作员 | - |
| 程序烧录 | 程序烧录操作员 / 产品测试操作员 | 历史映射并存 |
| 程序版本读取 | 产品测试操作员 | - |
| 发射功率测试 | 产品测试操作员 | - |
| 收发测试 | 产品测试操作员 | - |
| 产品焊接 | 产品组装操作员 | - |
| 产品组装 | 产品组装操作员 | - |
| 产品包装 | 产品包装操作员 | - |

## A8. 兼容性说明
1. 旧系统存在状态同义词兼容分支（如 `已完成` 与 `生产完成`）。
2. 工序角色映射在消息模块与订单模块存在历史差异，迁移时需统一字典源。
3. 页面可见性在配置缺失时会回落默认映射，可能与线上手工配置不一致。

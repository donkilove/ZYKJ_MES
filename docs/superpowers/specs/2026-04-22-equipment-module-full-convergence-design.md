# 设备模块完整收口设计

- 日期：2026-04-22
- 状态：已批准
- 负责人：Trae AI

## 1. 背景与目标

### 1.1 背景

设备模块是 MES 系统的重要模块之一，包含 6 个页签。当前 `EquipmentPage` 使用旧式 `Column + TabBar + TabBarView` 结构。

### 1.2 目标

按三批方式完成设备模块完整收口：
- 统一总页壳层
- 主业务页签使用统一组件模式
- 抽取模块级 widget
- 覆盖模块级 integration 测试

## 2. 范围

### 2.1 纳入范围

| 页签 | 当前状态 | 收口批次 |
|-----|---------|---------|
| 设备台账 | 未统一 | 第1批 |
| 保养项目 | 未统一 | 第2批 |
| 保养计划 | 未统一 | 第2批 |
| 保养执行 | 未统一 | 第3批 |
| 保养记录 | 未统一 | 第3批 |
| 规则与参数 | 未统一 | 第3批 |

### 2.2 排除范围

- 后端 API 修改

## 3. 分批实施

### 第1批：总页壳层 + 设备台账

#### 3.1.1 新增文件

| 文件 | 说明 |
|-----|------|
| `lib/features/equipment/presentation/widgets/equipment_page_shell.dart` | 总页壳层 |
| `lib/features/equipment/presentation/widgets/equipment_page_header.dart` | 统一页头 |

#### 3.1.2 修改文件

| 文件 | 改造内容 |
|-----|---------|
| `lib/features/equipment/presentation/equipment_page.dart` | 使用 `EquipmentPageShell` |

#### 3.1.3 验收标准

- [ ] `EquipmentPageShell` 存在且被 `EquipmentPage` 使用
- [ ] `EquipmentPageHeader` 存在
- [ ] 代码分析通过

---

### 第2批：保养项目 + 保养计划

#### 3.2.1 验收标准

- [ ] 保养项目页代码分析通过
- [ ] 保养计划页代码分析通过
- [ ] 单元测试通过

---

### 第3批：保养执行 + 保养记录 + 规则参数

#### 3.3.1 新增文件

| 文件 | 说明 |
|-----|------|
| `test/widgets/equipment_module_full_convergence_test.dart` | 模块级回归测试 |

#### 3.3.2 验收标准

- [ ] 保养执行页代码分析通过
- [ ] 保养记录页代码分析通过
- [ ] 规则参数页代码分析通过
- [ ] 模块级回归测试通过
- [ ] Integration 测试通过

---

## 4. 跨批次目标状态

### 4.1 架构模式

| 维度 | 目标 |
|-----|------|
| 总页壳层 | 使用 `EquipmentPageShell` |
| 子页统一页头 | 使用 `EquipmentPageHeader` |
| 主业务页 | 使用 `mes_crud_page_scaffold`（如适用） |
| 表格样式 | 使用 `CrudListTableSection` + `UnifiedListTableHeaderStyle` |

### 4.2 测试覆盖

| 测试文件 | 覆盖内容 |
|---------|---------|
| `equipment_module_full_convergence_test.dart` | 模块级完整回归 |
| `equipment_page_test.dart` | 总页壳层测试 |
| `equipment_module_pages_test.dart` | 各页签集成测试 |

## 5. 风险与约束

### 5.1 风险

- 设备模块涉及较长的业务链路

### 5.2 约束

- 不修改后端 API
- 保持权限控制不变
- 不引入新的路由

## 6. 迁移说明

- 无数据迁移
- 直接替换旧组件
- 旧组件在验证通过后删除

## 7. 验收检查清单

### 第1批完成检查

- [ ] `EquipmentPageShell` 已创建
- [ ] `EquipmentPageHeader` 已创建
- [ ] `EquipmentPage` 使用新壳层
- [ ] 代码分析通过

### 第2批完成检查

- [ ] 保养项目页代码分析通过
- [ ] 保养计划页代码分析通过
- [ ] 单元测试通过

### 第3批完成检查

- [ ] 保养执行页代码分析通过
- [ ] 保养记录页代码分析通过
- [ ] 规则参数页代码分析通过
- [ ] 模块级回归测试通过
- [ ] Integration 测试通过

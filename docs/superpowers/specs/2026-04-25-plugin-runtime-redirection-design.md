# 插件运行时目录重定向设计

- 日期：2026-04-25
- 主题：将插件运行时重定向为仓库内固定 Python 3.12 解释器与统一插件目录
- 状态：待用户审阅

## 1. 背景

当前插件宿主已经具备基本能力：

1. 能扫描插件目录并识别 `serial_assistant`
2. 插件中心可以显示插件入口
3. 宿主能尝试拉起 Python 插件进程

但当前运行时路径策略存在一个关键问题：

1. 宿主默认会尝试从 `frontend/build/windows/.../runtime/python/python.exe` 推断解释器路径
2. 这个路径依赖 Flutter 构建目录，不稳定，也不属于正式仓库结构
3. 一旦构建目录中没有对应解释器，插件就会在启动阶段直接失败

用户已经明确给出新的运行时要求：

1. 后续插件统一基于 Python 3.12 开发
2. Python 3.12 解释器直接提交进仓库
3. 项目根目录使用统一插件目录
4. 该目录同时承载：
   - Python 解释器
   - 各插件代码
5. 旧的构建目录回退逻辑应废弃

本设计的目标是把插件运行时从“构建目录下的临时推断”收敛成“仓库内固定路径”，使插件宿主、插件开发和交付口径统一。

## 2. 目标与非目标

### 2.1 目标

1. 固定插件根目录为仓库内 `plugins/`
2. 固定解释器路径为 `plugins/runtime/python312/python.exe`
3. 后续插件默认全部基于这一解释器开发和运行
4. 解释器作为仓库内容直接提交，不依赖初始化脚本动态下载
5. 插件私有依赖继续保持在各插件目录的 `vendor/` 下
6. 宿主在缺少解释器或插件目录时给出明确错误提示
7. 在 Python embeddable runtime 下，插件 `launcher.py` 负责显式组装 `sys.path`，宿主只传插件目录信息，不再把 `PYTHONPATH` 当成主加载机制

### 2.2 非目标

1. 本轮不升级插件协议
2. 本轮不扩展插件市场或安装器
3. 本轮不迁移插件依赖到公共 `site-packages`
4. 本轮不支持多版本解释器并存切换
5. 本轮不支持除 Python 3.12 以外的默认解释器

## 3. 方案选择

本轮采用：

**仓库内统一插件根目录 + 仓库内固定 Python 3.12 解释器**

不采用：

1. 继续从 `frontend/build/.../runtime/python` 推断解释器
   - 该路径不稳定，且与源代码目录边界不清
2. 每次启动时由脚本临时注入当前系统解释器
   - 会导致团队成员环境不一致
3. 首次启动时自动下载解释器
   - 违背用户希望“解释器直接进仓库”的要求

## 4. 目录结构

本轮统一采用以下目录结构：

```text
plugins/
  runtime/
    python312/
      python.exe
      pythonw.exe
      python312.dll
      python312.zip
      vcruntime140.dll
      vcruntime140_1.dll
      LICENSE.txt
      ...
  serial_assistant/
    manifest.json
    launcher.py
    app/
    vendor/
    web/
    logs/
```

设计原则：

1. `plugins/` 是唯一插件根目录
2. `plugins/runtime/python312/` 只放解释器运行时
3. `plugins/<plugin_id>/` 只放插件自身代码和依赖
4. 插件依赖继续由插件自身 `vendor/` 管理，不迁到公共运行时目录

## 5. 解释器目录最小内容

解释器目录应直接以 Python 3.12 Windows embeddable package 为基础。

建议至少包含：

1. `python.exe`
2. `pythonw.exe`
3. `python312.dll`
4. `python312.zip`
5. `vcruntime140.dll`
6. `vcruntime140_1.dll`
7. `LICENSE.txt`

解释器目录职责：

1. 仅承载 Python 运行时
2. 不承载插件业务代码
3. 不承载插件私有依赖
4. 不承载插件日志和缓存

## 6. 宿主定位规则

### 6.1 插件根目录

宿主默认插件根目录固定为：

```text
<repo>/plugins
```

可选允许：

1. `MES_PLUGIN_ROOT` 作为调试覆盖

但正式交付口径只认仓库根目录下的 `plugins/`。

### 6.2 Python 解释器

宿主默认解释器固定为：

```text
<repo>/plugins/runtime/python312/python.exe
```

可选允许：

1. `MES_PYTHON_RUNTIME_DIR` 作为调试覆盖

但正式交付口径只认仓库内固定解释器目录。

### 6.2.1 插件依赖装配方式

由于 Python embeddable runtime 处于隔离模式，宿主不再把 `PYTHONPATH` 作为主依赖装配机制。

统一口径改为：

1. 宿主启动前传递：
   - `MES_PLUGIN_DIR`
   - `MES_PLUGIN_VENDOR_DIR`
   - `MES_PLUGIN_APP_DIR`
2. 插件 `launcher.py` 自行把这些目录插入 `sys.path`
3. 插件私有依赖继续放在各插件目录的 `vendor/` 下

### 6.3 废弃规则

以下回退逻辑应废弃：

1. `frontend/build/.../runtime/python/python.exe`
2. 任意从 Flutter 构建目录派生解释器路径的逻辑

## 7. 仓库提交边界

### 7.1 应提交内容

1. `plugins/runtime/python312/` 下的 embeddable runtime 本体
2. `plugins/<plugin_id>/` 下的插件代码
3. `plugins/<plugin_id>/vendor/` 下的插件私有依赖

### 7.2 不应提交内容

1. `__pycache__/`
2. 临时解压目录
3. 日志文件
4. 构建输出目录
5. `pip cache`

### 7.3 .gitignore 策略

需要确保：

1. 运行时本体不被忽略
2. 插件私有依赖 `vendor/` 不被误忽略
3. Python 缓存与日志继续被忽略

## 8. 宿主错误处理

重定向后，宿主必须在以下情况给出明确错误提示：

### 8.1 插件根目录缺失

提示语义：

```text
插件目录缺失
```

### 8.2 Python 解释器缺失

提示语义：

```text
Python 运行时缺失
```

### 8.3 禁止神秘报错

宿主不应再把这类问题直接暴露成：

1. `ProcessException`
2. 构建目录路径找不到
3. 运行时派生路径错误

而应翻译成可理解的宿主错误文案。

## 9. 分批落地顺序

本轮按三批落地：

### 第一批：运行时定位改口径

修改：

1. `frontend/lib/features/plugin_host/services/plugin_runtime_locator.dart`
2. `start_frontend.py`
3. 对应测试

目标：

1. 固定解释器路径
2. 固定插件目录路径
3. 废弃构建目录回退逻辑

### 第二批：仓库目录与忽略规则调整

修改：

1. `.gitignore`
2. `plugins/runtime/python312/`
3. 交接文档或 README

目标：

1. 解释器进仓库
2. 忽略规则收口
3. 开发口径同步到文档

### 第三批：宿主错误文案与验证收口

修改：

1. `plugin_host_controller.dart`
2. `plugin_host_workspace.dart`
3. 对应 widget test
4. `evidence/`

目标：

1. 缺失目录/解释器时给出明确提示
2. 验证链与留痕闭环

## 10. 测试策略

至少覆盖以下验证：

### 10.1 运行时定位测试

1. 默认从 `<repo>/plugins/runtime/python312/python.exe` 取解释器
2. 默认从 `<repo>/plugins` 取插件根目录
3. 不再从 `frontend/build/.../runtime/python` 回退

### 10.2 启动脚本测试

1. `start_frontend.py` 启动时会把 `plugins/` 暴露给前端运行环境
2. 如保留环境变量覆盖，应验证优先级

### 10.3 宿主错误态测试

1. 插件目录缺失时提示正确
2. 解释器缺失时提示正确

### 10.4 人工验证

1. 仓库内放置 Python 3.12 解释器后，插件中心可正常启动 `serial_assistant`
2. 不设置额外环境变量时也能工作

## 11. 验收标准

以下 5 条同时满足即视为本轮重定向完成：

1. 仓库中存在 `plugins/runtime/python312/python.exe`
2. 宿主默认不再尝试访问 `frontend/build/.../runtime/python`
3. 不设置任何环境变量时，`serial_assistant` 仍可由宿主正常启动
4. 插件依赖继续使用各插件目录的 `vendor/`
5. 解释器缺失时，宿主显示明确错误提示，而不是神秘 `ProcessException`

## 12. 风险与取舍

1. 解释器直接提交进仓库会显著增加仓库体积
2. 解释器版本固定为 3.12，后续若升级需统一迁移全部插件
3. 将运行时固定进仓库能最大化稳定性，但牺牲了灵活升级能力

## 13. 推荐实施策略

推荐先完成本次运行时重定向，再继续增强插件功能。

也就是：

1. 先把“解释器在哪里”彻底定死
2. 再把“插件怎么启动”验证通过
3. 最后再继续做 `serial_assistant` 或其他插件功能增强

原因：

1. 运行时定位属于宿主根基
2. 若不先稳定这层，后续插件功能迭代仍会被启动问题反复打断

## 14. 迁移说明

- 无迁移，直接替换

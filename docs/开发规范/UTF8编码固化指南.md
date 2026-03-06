# UTF-8 编码固化指南

## 目标
- 仓库内文本文件统一使用 `UTF-8（无 BOM）`。
- 行尾统一使用 `LF`。
- 通过本地自检和 GitHub Actions 双重门禁，阻断乱码进入主分支。

## 仓库级约束
- `.editorconfig`：统一编辑器保存行为（UTF-8、LF、去尾空格、文件末尾换行）。
- `.gitattributes`：统一 Git 文本行尾规则（`* text=auto eol=lf`），并对二进制后缀显式标记 `binary`。

首次启用后建议在独立提交中执行一次归一化：

```bash
git add --renormalize .
git status
```

确认仅为行尾/规范化改动后，单独提交该规范化提交，不与业务功能提交混合。

## Agent 执行约束
- 以仓库根 `AGENTS.md` 为执行最高优先级。
- 所有新增/修改文本文件必须为 `UTF-8（无 BOM）`。
- 全仓库文本行尾统一为 `LF`。
- 不允许跳过编码检查；任一检查失败即任务未完成。
- 代码修改后必须执行并汇报：
  - `python backend/scripts/check_chinese_mojibake.py`
  - `python backend/scripts/check_frontend_chinese_mojibake.py`
  - `python -m pytest test/backend/test_chinese_mojibake_check.py test/backend/test_frontend_chinese_mojibake_check.py -q`
- Windows 写文件时需显式指定 UTF-8 无 BOM（PowerShell 示例：`UTF8Encoding($false)`）。

## 本地乱码检查命令
后端 Python 源码检查：

```bash
python backend/scripts/check_chinese_mojibake.py
```

前端 Dart 源码检查：

```bash
python backend/scripts/check_frontend_chinese_mojibake.py
```

本地自动修复可逆乱码（谨慎使用，修复后需人工复核）：

```bash
python backend/scripts/check_chinese_mojibake.py --fix
python backend/scripts/check_frontend_chinese_mojibake.py --fix
```

门禁测试（必须通过）：

```bash
python -m pytest test/backend/test_chinese_mojibake_check.py test/backend/test_frontend_chinese_mojibake_check.py -q
```

## 提交前最小自检清单
1. 新增/修改文本文件均为 UTF-8 无 BOM。
2. 行尾均为 LF。
3. 后端乱码扫描通过。
4. 前端乱码扫描通过。
5. 两条编码门禁 pytest 通过。
6. 本次提交信息使用中文（除非用户明确要求其它语言）。

## GitHub Actions 门禁
工作流文件：`.github/workflows/encoding-guard.yml`

触发条件：
- `push`
- `pull_request`

执行内容：
1. 安装 Python 与依赖。
2. 运行后端/前端乱码扫描脚本（扫描模式）。
3. 运行 `pytest` 编码门禁测试。

任一步失败都会阻断合并。

## Git 推荐配置（团队统一）

```bash
git config --global core.autocrlf false
git config --global core.safecrlf true
git config --global i18n.commitencoding utf-8
git config --global i18n.logoutputencoding utf-8
```

## Windows 终端建议

```powershell
chcp 65001
```

建议同时使用支持 UTF-8 的终端字体，避免“显示乱码但文件实际正常”的误判。

## IDE 固化建议
- 默认文件编码：`UTF-8`（无 BOM）。
- 默认行尾：`LF`。
- 开启保存时去除行尾空格。
- 开启文件末尾自动换行。

## 常见误区（终端显示乱码 vs 文件真实编码）
- 误区 1：终端显示乱码就等于文件损坏。
  - 事实：常见原因是终端代码页不对，文件本身可能仍是 UTF-8。
  - 检查方式：用脚本读取字节并验证是否有 BOM、是否包含 CRLF。
- 误区 2：Windows 默认 Git 配置不影响编码。
  - 事实：`autocrlf` 会改写行尾，若团队策略是 LF，会引入差异噪音。
- 误区 3：编辑器“自动猜测编码”是安全的。
  - 事实：UTF-8 文件按 GBK 打开并保存会造成不可逆乱码。

## 常见乱码根因与避免方式
- 根因 1：UTF-8 文件被按 GBK/ANSI 打开后再次保存。
  - 避免：IDE 强制 UTF-8，禁止“自动猜测编码后覆盖保存”。
- 根因 2：Windows `autocrlf` 自动改写行尾引发混乱。
  - 避免：统一 `core.autocrlf=false`，仓库使用 `.gitattributes` 固定 LF。
- 根因 3：复制外部文本时携带不可见异常字符。
  - 避免：提交前执行扫描脚本与 pytest 门禁测试。
- 根因 4：在未统一编码策略前混合多人开发。
  - 避免：将本规范纳入入项步骤，并在 PR 模板中加入编码自检项。

## 提交信息约束
- Git 提交信息默认使用中文。
- 若用户在单次任务中明确要求其它语言，则按该次要求执行。

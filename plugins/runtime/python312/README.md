# Python 3.12.10 固定运行时

本目录固定存放仓库内置的 Windows 64-bit Python 3.12.10 embeddable runtime。

## 目录约定

- 固定解释器路径：`plugins/runtime/python312/python.exe`
- 插件根目录：`plugins/`
- 适用场景：仓库内插件或脚本需要统一、可重复的 Python 运行时
- 平台边界：当前仅支持 Windows x64

## 来源

- 官方版本：Python 3.12.10
- 包类型：Windows embeddable package (64-bit)
- 官方下载：`https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip`

## 使用说明

以下场景必须使用本目录内置解释器：

- 运行仓库内插件
- 复现插件相关问题
- 编写或执行要求固定插件运行时的脚本
- 需要保证多人、CI 与本地一致时

以下场景可以继续使用系统 Python：

- 仓库根级启动脚本或开发者个人工具链未依赖插件固定运行时
- 任务只要求通用 Python 能力，且不涉及 `plugins/` 下插件的可重复复现

直接执行：

```powershell
& .\plugins\runtime\python312\python.exe -c "import sys; print(sys.version)"
```

## 维护口径

- 当前目录按官方 `Python 3.12.10 Windows embeddable package (64-bit)` 原样入仓，仅额外保留本说明文件；日常维护不允许裁剪、替换或增删运行时二进制内容。
- 本目录中的运行时二进制属于仓库受控内容，不通过安装器动态下载。
- 整目录入仓是为了同时锁定解释器、标准库压缩包、动态库和扩展模块，避免插件在其他机器上因为缺失依赖或系统 Python 差异而失效。
- 升级或替换步骤：
  1. 下载新的官方 Windows embeddable package (64-bit)。
  2. 用整包内容替换 `plugins/runtime/python312/` 中现有官方文件，仅同步更新本 `README.md` 所述版本信息。
  3. 执行 `git check-ignore -v plugins/runtime/python312/python.exe`，确认解释器本体未被忽略。
  4. 执行 `& .\plugins\runtime\python312\python.exe -c "import sys; print(sys.version)"`，确认输出目标版本。
- 校验口径：解释器文件必须纳入版本控制，版本输出必须与目录声明一致；否则视为替换未完成。
- 忽略规则只继续忽略缓存、日志、临时文件与系统噪音，不忽略运行时本体与插件 `vendor` 受控内容。
- 无迁移，直接替换。

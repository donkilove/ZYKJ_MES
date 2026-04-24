# Python 3.12.10 固定运行时

本目录固定存放仓库内置的 Windows 64-bit Python 3.12.10 embeddable runtime。

## 目录约定

- 固定解释器路径：`plugins/runtime/python312/python.exe`
- 插件根目录：`plugins/`
- 适用场景：仓库内插件或脚本需要统一、可重复的 Python 运行时

## 来源

- 官方版本：Python 3.12.10
- 包类型：Windows embeddable package (64-bit)
- 官方下载：`https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip`

## 使用说明

直接执行：

```powershell
& .\plugins\runtime\python312\python.exe -c "import sys; print(sys.version)"
```

## 维护口径

- 本目录中的运行时二进制属于仓库受控内容，不通过安装器动态下载。
- 忽略规则只继续忽略缓存与日志，不忽略运行时本体与插件 `vendor` 内容。
- 无迁移，直接替换。

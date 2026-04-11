# PyCharm 中 Claude Code GUI 接入 `MCP_DOCKER`

## 目标

为本仓库内通过 PyCharm 打开的 Claude Code GUI 提供项目级 `MCP_DOCKER` 接入配置，避免依赖用户级 `~/.claude.json` 的本机状态漂移。

## 本次方案

仓库根目录新增项目级 `.mcp.json`，按 Claude Code 官方的项目共享配置格式声明 `MCP_DOCKER`。

与用户级常见配置 `docker mcp gateway run` 不同，本仓库固定改为直接调用：

```text
C:\Program Files\Docker\cli-plugins\docker-mcp.exe gateway run
```

项目文件里实际使用环境变量展开后的等价写法：

```json
{
  "mcpServers": {
    "MCP_DOCKER": {
      "command": "${ProgramFiles}/Docker/cli-plugins/docker-mcp.exe",
      "args": ["gateway", "run"]
    }
  }
}
```

这样做的原因：

1. Claude Code 官方支持在项目根目录使用 `.mcp.json` 共享 MCP server 配置。
2. JetBrains 中的 Claude Code GUI 复用 Claude Code 自身配置体系，因此会读取该项目级文件。
3. 本仓库此前已排查过 `docker mcp gateway run` 在 CC GUI 场景下可能命中兼容性问题，直接调用 `docker-mcp.exe` 更稳。

## 使用方式

1. 用 PyCharm 打开仓库根目录。
2. 确认 Claude Code JetBrains 插件已启用。
3. 完全重启一次 PyCharm，或至少重开 Claude Code 会话页签。
4. 首次读取项目级 `.mcp.json` 时，如 GUI 弹出项目 MCP 授权提示，选择允许。

## 最小自检

可先在 PowerShell 执行以下命令确认宿主侧命令可用：

```powershell
& 'C:\Program Files\Docker\cli-plugins\docker-mcp.exe' gateway run --help
```

若命令正常输出 `Usage: docker mcp gateway run`，说明 CC GUI 所需的底层启动命令存在。

随后在 PyCharm 的 Claude Code GUI 中要求其列出当前可用 MCP server；若看到 `MCP_DOCKER`，则项目级接入已生效。

## 边界说明

- 本次只覆盖 PyCharm 中的 Claude Code GUI。
- JetBrains 自带 AI Assistant / Junie 的 MCP Project Settings 不在本次改动范围内。
- 无迁移，直接替换。

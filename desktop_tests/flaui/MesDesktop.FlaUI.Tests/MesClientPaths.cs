using System.Diagnostics;

namespace MesDesktop.FlaUI.Tests;

internal static class MesClientPaths
{
    private const string ExecutableOverrideVariable = "MES_CLIENT_EXE_PATH";
    private static readonly string DefaultRelativeExecutablePath = Path.Combine(
        "frontend",
        "build",
        "windows",
        "x64",
        "runner",
        "Debug",
        "mes_client.exe");

    internal static string ExecutableOverrideVariableName => ExecutableOverrideVariable;

    internal static string ResolveExecutablePath()
    {
        var overridePath = Environment.GetEnvironmentVariable(ExecutableOverrideVariable);
        if (!string.IsNullOrWhiteSpace(overridePath))
        {
            return Path.GetFullPath(Environment.ExpandEnvironmentVariables(overridePath));
        }

        var repoRoot = FindRepositoryRoot();
        return Path.Combine(repoRoot, DefaultRelativeExecutablePath);
    }

    internal static string FindRepositoryRootForTests()
    {
        return FindRepositoryRoot();
    }

    internal static string BuildMissingExecutableMessage(string executablePath)
    {
        return $"未找到 mes_client.exe。请先构建 Flutter Windows 客户端，或通过环境变量 {ExecutableOverrideVariable} 指向可执行文件。当前解析路径：{executablePath}";
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            var frontendDirectory = Path.Combine(current.FullName, "frontend");
            var agentFile = Path.Combine(current.FullName, "AGENTS.md");
            if (Directory.Exists(frontendDirectory) && File.Exists(agentFile))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new DirectoryNotFoundException("无法从测试运行目录向上定位仓库根目录，无法解析默认 mes_client.exe 路径。");
    }
}

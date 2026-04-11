using System.Diagnostics;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Tools;
using FlaUI.UIA3;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace MesDesktop.FlaUI.Tests;

[TestClass]
public sealed class SmokeTests
{
    [TestMethod]
    public void 应可启动_mes_client_并等待主窗口出现()
    {
        var executablePath = string.Empty;
        global::FlaUI.Core.Application? application = null;
        Process? process = null;

        try
        {
            executablePath = MesClientPaths.ResolveExecutablePath();
            if (!File.Exists(executablePath))
            {
                Assert.Fail(MesClientPaths.BuildMissingExecutableMessage(executablePath));
            }

            application = global::FlaUI.Core.Application.Launch(executablePath);
            process = Process.GetProcessById(application.ProcessId);

            using var automation = new UIA3Automation();
            var mainWindow = WaitForMainWindow(application, automation);

            Assert.IsNotNull(mainWindow, $"已启动进程但未在超时内附着到主窗口。PID={process?.Id}，路径：{executablePath}");
            Assert.IsFalse(string.IsNullOrWhiteSpace(mainWindow.Title), $"主窗口已出现，但标题为空。PID={process?.Id}，路径：{executablePath}");

            TestContext.WriteLine($"Smoke 通过：已启动并附着到主窗口。PID={process?.Id}，标题：{mainWindow.Title}，路径：{executablePath}");
        }
        catch (AssertFailedException)
        {
            throw;
        }
        catch (Exception ex)
        {
            Assert.Fail($"Smoke 失败：基础设施或运行阶段异常。异常类型：{ex.GetType().FullName}；原因：{ex.Message}；路径：{executablePath}");
        }
        finally
        {
            CleanupProcess(application, process);
        }
    }

    public TestContext TestContext { get; set; } = null!;

    private static Window? WaitForMainWindow(global::FlaUI.Core.Application application, UIA3Automation automation)
    {
        var retryResult = Retry.WhileNull(
            () => application.GetMainWindow(automation),
            timeout: TimeSpan.FromSeconds(20),
            interval: TimeSpan.FromMilliseconds(500),
            throwOnTimeout: false,
            ignoreException: true);

        return retryResult.Result;
    }

    private static void CleanupProcess(global::FlaUI.Core.Application? application, Process? process)
    {
        try
        {
            application?.Close();
        }
        catch
        {
            // 关闭窗口失败时继续尝试终止进程，避免测试残留。
        }

        try
        {
            if (process is { HasExited: false })
            {
                process.Kill(entireProcessTree: true);
                process.WaitForExit(5000);
            }
        }
        catch
        {
            // 清理阶段不覆盖原始测试结论。
        }
        finally
        {
            process?.Dispose();
            application?.Dispose();
        }
    }
}

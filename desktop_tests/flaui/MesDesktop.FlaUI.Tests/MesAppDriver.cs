using System.Diagnostics;
using System.Net.Sockets;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Conditions;
using FlaUI.Core.Tools;
using FlaUI.UIA3;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace MesDesktop.FlaUI.Tests;

internal sealed class MesAppDriver : IDisposable
{
    private readonly Process? backendProcess;
    private readonly global::FlaUI.Core.Application application;
    private readonly Process? clientProcess;
    private bool disposed;

    private MesAppDriver(Process? backendProcess, global::FlaUI.Core.Application application, Process? clientProcess, UIA3Automation automation, Window mainWindow)
    {
        this.backendProcess = backendProcess;
        this.application = application;
        this.clientProcess = clientProcess;
        Automation = automation;
        MainWindow = mainWindow;
    }

    internal UIA3Automation Automation { get; }

    internal Window MainWindow { get; }

    internal static MesAppDriver Launch(bool withBackend, TestContext testContext)
    {
        var backendProcess = withBackend ? StartBackend(testContext) : null;

        var executablePath = MesClientPaths.ResolveExecutablePath();
        if (!File.Exists(executablePath))
        {
            Assert.Fail(MesClientPaths.BuildMissingExecutableMessage(executablePath));
        }

        var application = global::FlaUI.Core.Application.Launch(executablePath);
        Process? clientProcess = null;
        try
        {
            clientProcess = Process.GetProcessById(application.ProcessId);
            var automation = new UIA3Automation();
            var mainWindow = Retry.WhileNull(
                () => application.GetMainWindow(automation),
                timeout: TimeSpan.FromSeconds(25),
                interval: TimeSpan.FromMilliseconds(500),
                throwOnTimeout: false,
                ignoreException: true).Result;

            if (mainWindow is null)
            {
                throw new InvalidOperationException($"已启动 mes_client.exe，但未在超时内获取主窗口。PID={clientProcess?.Id}");
            }

            testContext.WriteLine($"应用已启动。客户端 PID={clientProcess?.Id}，窗口标题={mainWindow.Title}");
            return new MesAppDriver(backendProcess, application, clientProcess, automation, mainWindow);
        }
        catch
        {
            clientProcess?.Dispose();
            application.Dispose();
            backendProcess?.Dispose();
            throw;
        }
    }

    internal AutomationElement WaitForElement(Func<ConditionFactory, ConditionBase> conditionFactory, TimeSpan timeout, string description)
    {
        var result = Retry.WhileNull(
            () => MainWindow.FindFirstDescendant(conditionFactory),
            timeout,
            TimeSpan.FromMilliseconds(500),
            throwOnTimeout: false,
            ignoreException: true).Result;

        if (result is null)
        {
            throw new AssertFailedException($"在超时内未找到元素：{description}");
        }

        return result;
    }

    internal AutomationElement? FindByName(string name)
    {
        return MainWindow.FindFirstDescendant(cf => cf.ByName(name));
    }

    internal IReadOnlyList<AutomationElement> FindAllByName(string name)
    {
        return MainWindow.FindAllDescendants(cf => cf.ByName(name));
    }

    internal AutomationElement? FindFirstDescendant(Func<ConditionFactory, ConditionBase> conditionFactory)
    {
        return MainWindow.FindFirstDescendant(conditionFactory);
    }

    internal IReadOnlyList<Window> GetAllTopLevelWindows()
    {
        return application.GetAllTopLevelWindows(Automation);
    }

    public void Dispose()
    {
        if (disposed)
        {
            return;
        }

        disposed = true;

        try
        {
            application.Close();
        }
        catch
        {
            // 关闭窗口失败时继续终止进程，避免残留。
        }

        try
        {
            Automation.Dispose();
        }
        catch
        {
            // 清理阶段不覆盖原始测试结论。
        }

        KillProcess(clientProcess);
        KillProcess(backendProcess);

        clientProcess?.Dispose();
        application.Dispose();
        backendProcess?.Dispose();
    }

    private static Process StartBackend(TestContext testContext)
    {
        var repoRoot = MesClientPaths.FindRepositoryRootForTests();
        var pythonPath = Path.Combine(repoRoot, ".venv", "Scripts", "python.exe");
        if (!File.Exists(pythonPath))
        {
            Assert.Fail($"未找到测试约定的 Python 解释器：{pythonPath}");
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = pythonPath,
            Arguments = "start_backend.py --no-reload",
            WorkingDirectory = repoRoot,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };
        startInfo.Environment["NO_PROXY"] = "localhost,127.0.0.1,::1";
        startInfo.Environment["no_proxy"] = "localhost,127.0.0.1,::1";

        var process = Process.Start(startInfo);
        if (process is null)
        {
            Assert.Fail("后端启动失败：无法创建 start_backend.py 进程。");
        }

        if (!WaitForPort("127.0.0.1", 8000, TimeSpan.FromSeconds(40)))
        {
            var stdError = process.StandardError.ReadToEnd();
            throw new AssertFailedException($"后端未在超时内监听 8000 端口。stderr={stdError}");
        }

        testContext.WriteLine($"后端已启动。PID={process.Id}");
        return process;
    }

    private static bool WaitForPort(string host, int port, TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            try
            {
                using var tcpClient = new TcpClient();
                var connectTask = tcpClient.ConnectAsync(host, port);
                if (connectTask.Wait(TimeSpan.FromSeconds(1)) && tcpClient.Connected)
                {
                    return true;
                }
            }
            catch
            {
                // 继续重试，等待服务就绪。
            }

            Thread.Sleep(500);
        }

        return false;
    }

    private static void KillProcess(Process? process)
    {
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
    }
}

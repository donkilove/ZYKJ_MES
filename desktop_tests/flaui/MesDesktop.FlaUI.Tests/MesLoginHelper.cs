using FlaUI.Core.AutomationElements;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace MesDesktop.FlaUI.Tests;

internal static class MesLoginHelper
{
    private const string DefaultBaseUrl = "http://127.0.0.1:8000";
    private static readonly TimeSpan ShellEntryGracePeriod = TimeSpan.FromSeconds(12);
    private static readonly string[] ShellWelcomeCandidates = ["工作台", "欢迎使用 ZYKJ MES 系统", "欢迎使用"];
    private static readonly string[] ShellNavigationCandidates = ["用户", "产品", "工艺", "生产", "设备"];
    private static readonly string[] ShellSupplementaryCandidates = ["质量", "品质"];
    private static readonly string[] ShellLandmarkCandidates = ["用户", "产品", "工艺", "生产", "设备", "质量", "品质", "消息"];

    internal static void LoginAsAdmin(MesAppDriver app)
    {
        FillLoginForm(app);
        var loginButton = app.WaitForElement(cf => cf.ByName("登录"), TimeSpan.FromSeconds(20), "登录按钮").AsButton();
        loginButton.Click();
    }

    internal static (string BaseUrl, string Account, string Password) FillLoginForm(MesAppDriver app)
    {
        var baseUrlEdit = app.WaitForElement(cf => cf.ByName("接口地址"), TimeSpan.FromSeconds(20), "接口地址输入框").AsTextBox();
        var accountEdit = app.WaitForElement(cf => cf.ByName("账号"), TimeSpan.FromSeconds(20), "账号输入框").AsTextBox();
        var passwordEdit = app.WaitForElement(cf => cf.ByName("密码"), TimeSpan.FromSeconds(20), "密码输入框").AsTextBox();

        if (!TryGetText(baseUrlEdit, out var currentBaseUrl) || string.IsNullOrWhiteSpace(currentBaseUrl) || !currentBaseUrl.StartsWith("http", StringComparison.OrdinalIgnoreCase))
        {
            SetText(baseUrlEdit, DefaultBaseUrl, clearExisting: true);
        }

        SetText(accountEdit, "admin", clearExisting: true);
        SetText(passwordEdit, "Admin@123456", clearExisting: true);
        return (
            GetTextOrPlaceholder(baseUrlEdit),
            GetTextOrPlaceholder(accountEdit),
            GetTextOrPlaceholder(passwordEdit));
    }

    internal static void AssertAnyTextVisible(MesAppDriver app, IEnumerable<string> candidates, TimeSpan timeout, string description)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            foreach (var candidate in candidates)
            {
                if (app.FindByName(candidate) is not null)
                {
                    return;
                }
            }

            Thread.Sleep(500);
        }

        throw new AssertFailedException($"在超时内未看到 {description}。候选文本：{string.Join('、', candidates)}");
    }

    internal static void WaitForShellReady(MesAppDriver app, TimeSpan timeout, Action<string>? log = null)
    {
        var deadline = DateTime.UtcNow + timeout;
        ShellSnapshot? lastSnapshot = null;
        DateTime? skeletonReadySince = null;
        DateTime? graceDeadline = null;

        while (DateTime.UtcNow < (graceDeadline is { } extended && extended > deadline ? extended : deadline))
        {
            lastSnapshot = CaptureShellSnapshot(app);
            if (lastSnapshot.IsReady)
            {
                log?.Invoke($"主壳层就绪：{lastSnapshot}");
                return;
            }

            if (lastSnapshot.HasStableShellSkeleton)
            {
                if (!skeletonReadySince.HasValue)
                {
                    skeletonReadySince = DateTime.UtcNow;
                    graceDeadline = skeletonReadySince.Value + ShellEntryGracePeriod;
                    log?.Invoke($"主壳层骨架已就绪，继续等待关键入口：{lastSnapshot}");
                }

                if (graceDeadline is { } stableUntil && DateTime.UtcNow >= stableUntil)
                {
                    log?.Invoke($"主壳层关键入口延迟暴露，按稳定骨架放行后续显式断言：{lastSnapshot}");
                    return;
                }
            }
            else
            {
                skeletonReadySince = null;
                graceDeadline = null;
            }

            Thread.Sleep(500);
        }

        throw new AssertFailedException(
            $"在超时内未等待到主壳层就绪。最后一次观测：{lastSnapshot?.ToString() ?? "<none>"}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 3)}");
    }

    private static void SetText(TextBox textBox, string value, bool clearExisting)
    {
        try
        {
            textBox.Text = value;
            return;
        }
        catch
        {
            // Flutter 的 ValuePattern 行为可能受限，回退为模拟输入。
        }

        textBox.Click();
        textBox.Focus();
        Thread.Sleep(200);

        if (clearExisting)
        {
            Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_A);
            Thread.Sleep(100);
            Keyboard.Type(VirtualKeyShort.DELETE);
            Thread.Sleep(100);
        }

        foreach (var character in value)
        {
            Keyboard.Type(character);
            Thread.Sleep(50);
        }
    }

    internal static bool TryGetText(TextBox textBox, out string value)
    {
        try
        {
            value = textBox.Text ?? string.Empty;
            return true;
        }
        catch
        {
            value = string.Empty;
            return false;
        }
    }

    private static string GetTextOrPlaceholder(TextBox textBox)
    {
        return TryGetText(textBox, out var value) ? value : "<unavailable>";
    }

    private static ShellSnapshot CaptureShellSnapshot(MesAppDriver app)
    {
        var namedElements = EnumerateSearchRoots(app)
            .SelectMany(root => root.FindAllDescendants().Prepend(root))
            .Select(GetSafeName)
            .Where(static name => !string.IsNullOrWhiteSpace(name))
            .ToList();

        var navigationHits = CountContains(namedElements, ShellNavigationCandidates);
        var hasWelcome = ContainsAny(namedElements, ShellWelcomeCandidates);
        var hasSupplementaryNavigation = ContainsAny(namedElements, ShellSupplementaryCandidates);
        var hasMessageEntry = namedElements.Any(static name => name.Contains("消息", StringComparison.Ordinal));
        var landmarkHits = CountContains(namedElements, ShellLandmarkCandidates);
        var hasUserEntry = namedElements.Any(static name => name.Contains("用户", StringComparison.Ordinal));

        return new ShellSnapshot(hasWelcome, navigationHits, hasSupplementaryNavigation, hasMessageEntry, landmarkHits, hasUserEntry);
    }

    private static IEnumerable<AutomationElement> EnumerateSearchRoots(MesAppDriver app)
    {
        yield return app.MainWindow;
        foreach (var window in app.GetAllTopLevelWindows())
        {
            if (!ReferenceEquals(window, app.MainWindow))
            {
                yield return window;
            }
        }
    }

    private static int CountContains(IEnumerable<string> values, IEnumerable<string> candidates)
    {
        var hits = 0;
        foreach (var candidate in candidates)
        {
            if (values.Any(value => value.Contains(candidate, StringComparison.Ordinal)))
            {
                hits++;
            }
        }

        return hits;
    }

    private static bool ContainsAny(IEnumerable<string> values, IEnumerable<string> candidates)
    {
        foreach (var candidate in candidates)
        {
            if (values.Any(value => value.Contains(candidate, StringComparison.Ordinal)))
            {
                return true;
            }
        }

        return false;
    }

    private static string GetSafeName(AutomationElement element)
    {
        try
        {
            return element.Name ?? string.Empty;
        }
        catch
        {
            return string.Empty;
        }
    }

    private sealed record ShellSnapshot(bool HasWelcome, int NavigationHits, bool HasSupplementaryNavigation, bool HasMessageEntry, int LandmarkHits, bool HasUserEntry)
    {
        internal bool HasStableShellSkeleton => LandmarkHits >= 5
            || (NavigationHits >= 4 && (HasSupplementaryNavigation || HasMessageEntry))
            || (HasWelcome && NavigationHits >= 3 && HasSupplementaryNavigation)
            || (NavigationHits >= 3 && HasSupplementaryNavigation);

        internal bool IsReady => HasUserEntry && (LandmarkHits >= 5
            || (NavigationHits >= 4 && (HasSupplementaryNavigation || HasMessageEntry))
            || (HasWelcome && NavigationHits >= 3 && HasSupplementaryNavigation)
            || (NavigationHits >= 3 && HasSupplementaryNavigation));

        public override string ToString()
        {
            return $"欢迎区={(HasWelcome ? "已命中" : "未命中")}，主导航命中={NavigationHits}，组合地标命中={LandmarkHits}，用户导航={(HasUserEntry ? "已命中" : "未命中")}，质量导航={(HasSupplementaryNavigation ? "已命中" : "未命中")}，消息入口={(HasMessageEntry ? "已命中" : "未命中")}";
        }
    }
}

using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Exceptions;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Text.RegularExpressions;

namespace MesDesktop.FlaUI.Tests;

[TestClass]
public sealed class DesktopNavigationTests
{
    private static readonly string[] ShellNavigationCandidates = ["用户", "产品", "工艺", "生产", "设备"];
    private static readonly string[] UserModuleTabCandidates = ["用户管理", "注册审批", "角色管理", "审计日志", "个人中心", "登录会话", "功能权限配置"];

    public TestContext TestContext { get; set; } = null!;

    [TestMethod]
    public void 登录页应显示关键输入与操作元素()
    {
        using var app = MesAppDriver.Launch(withBackend: false, TestContext);

        var requiredNames = new[] { "ZYKJ MES 登录", "接口地址", "账号", "密码", "登录" };
        foreach (var requiredName in requiredNames)
        {
            Assert.IsNotNull(app.FindByName(requiredName), $"登录页未找到关键元素：{requiredName}");
        }
    }

    [TestMethod]
    public void 管理员登录后应进入主壳层并显示关键导航()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        MesLoginHelper.LoginAsAdmin(app);

        MesLoginHelper.WaitForShellReady(app, TimeSpan.FromSeconds(30), TestContext.WriteLine);

        foreach (var candidate in ShellNavigationCandidates)
        {
            Assert.IsNotNull(FindNamedNavigationElement(app, candidate), $"主壳层未找到导航文本：{candidate}");
        }

        Assert.IsTrue(HasAnyNamedElement(app, new[] { "质量", "品质" }), "主壳层未找到质量/品质导航文本。当前 UIA 可能存在文案不一致。" );
        Assert.IsNotNull(FindMessageEntry(app), "主壳层未找到消息入口按钮。");
    }

    [TestMethod]
    public void 进入消息中心后应看到页面标题与列表元素()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        LoginAndWaitForShell(app);

        var messageEntry = FindMessageEntry(app);
        Assert.IsNotNull(messageEntry, "未找到消息入口按钮。");
        messageEntry.Click();

        MesLoginHelper.AssertAnyTextVisible(app, new[] { "消息中心", "全部消息" }, TimeSpan.FromSeconds(20), "消息中心标题");
        Assert.IsNotNull(app.FindByName("搜索标题/摘要"), "消息中心未找到搜索输入框。" );
        Assert.IsTrue(HasAnyNamedElement(app, new[] { "详情", "跳转", "全部已读" }), "消息中心未找到列表操作按钮或页面操作按钮。" );
    }

    [TestMethod]
    public void 登录后进入用户模块应显示关键业务页签()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        LoginAndWaitForShell(app);
        OpenUserModule(app);

        Assert.IsTrue(
            FindNamedInteractiveElement(app, "用户管理") is not null
            || FindNamedInteractiveElement(app, "注册审批") is not null,
            "用户模块未出现可验证的业务页签。"
        );
    }

    [TestMethod]
    public void 打开用户管理后应看到关键按钮与表头()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        LoginAndWaitForShell(app);
        OpenUserModule(app);

        ClickNamedInteractiveElement(app, "用户管理", "用户管理页签");
        AssertAnyNamedElementVisible(app, new[] { "角色管理", "账号", "角色", "状态" }, TimeSpan.FromSeconds(25), "用户管理关键按钮或表头");
    }

    [TestMethod]
    public void 打开注册审批后应看到关键筛选与表头()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        LoginAndWaitForShell(app);
        OpenUserModule(app);

        ClickNamedInteractiveElement(app, "注册审批", "注册审批页签");
        AssertAnyNamedElementVisible(app, new[] { "申请状态", "用户名", "待审批" }, TimeSpan.FromSeconds(25), "注册审批关键筛选或表头");
    }

    [TestMethod]
    public void T27_个人中心可进入并显示关键区域()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        LoginAndWaitForShell(app);
        OpenUserModule(app);

        var opened = EnsureUserModulePageVisible(
            app,
            "个人中心",
            new[] { "个人中心主区域", "个人中心", "修改密码", "当前会话", "用户名" },
            allowWitnessWithoutTabClick: true);
        Assert.IsTrue(opened, $"个人中心入口未稳定暴露，且未观察到页面关键区域。{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 4)}");
    }

    [TestMethod]
    public void T27_登录会话可进入并显示关键表头与操作()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        LoginAndWaitForShell(app);
        OpenUserModule(app);

        SelectUserModuleTab(app, "登录会话", new[] { "登录会话主区域", "登录会话筛选与操作区", "在线会话列表区域", "在线会话", "关键词", "强制下线", "用户名" });
        AssertAnyNamedElementVisible(app, new[] { "登录会话主区域", "登录会话筛选与操作区", "在线会话列表区域", "在线会话", "关键词", "强制下线", "用户名" }, TimeSpan.FromSeconds(25), "登录会话关键表头或按钮");
    }

    [TestMethod]
    [Ignore("当前登录会话页对 API 新建会话的目标行未稳定暴露到 UIA 列表，保留为 T27 阻塞项。")]
    public void T27_登录会话对目标账号执行单个强制下线后列表应刷新()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        var sessionSeed = MesUserModuleSeedHelper.CreateOnlineSessionSeed(TestContext);

        LoginAndWaitForShell(app);
        OpenUserModule(app);
        SelectUserModuleTab(app, "登录会话", new[] { "在线会话", "关键词", "强制下线", "用户名" });
        FillAnyTextBoxByNames(app, new[] { "关键词", "用户名" }, sessionSeed.Username, submit: true, "登录会话关键词筛选框");
        TryClickAnyNamedInteractiveElement(app, new[] { "查询" }, "登录会话查询按钮");
        AssertElementContainingTextVisible(app, sessionSeed.Username, TimeSpan.FromSeconds(25), "目标在线会话行");

        ClickRowButtonNearText(app, sessionSeed.Username, "强制下线", "登录会话强制下线按钮");
        AssertFilteredRowEventuallyDisappears(app, sessionSeed.Username, TimeSpan.FromSeconds(25), "登录会话强制下线结果");
    }

    [TestMethod]
    public void T27_角色管理可进入并显示关键按钮与表头()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        LoginAndWaitForShell(app);
        OpenUserModule(app);

        SelectUserModuleTab(app, "角色管理", new[] { "角色名称", "新增角色", "关键词", "状态" });
        AssertAnyNamedElementVisible(app, new[] { "角色名称", "新增角色", "关键词", "状态" }, TimeSpan.FromSeconds(25), "角色管理关键按钮或表头");
    }

    [TestMethod]
    public void T27_角色管理删除目标角色后列表应刷新()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        var roleSeed = MesUserModuleSeedHelper.CreateRoleManagementDeleteSeed(TestContext);

        LoginAndWaitForShell(app);
        OpenUserModule(app);
        SelectUserModuleTab(app, "角色管理", new[] { "角色名称", "新增角色", "关键词", "状态" });
        FillAnyTextBoxByNames(app, new[] { "关键词", "角色名称" }, roleSeed.RoleName, submit: true, "角色管理关键词筛选框");
        TryClickAnyNamedInteractiveElement(app, new[] { "查询" }, "角色管理查询按钮");
        AssertElementContainingTextVisible(app, roleSeed.RoleName, TimeSpan.FromSeconds(25), "目标角色行");

        ClickRowButtonNearText(app, roleSeed.RoleName, "删除", "角色管理删除按钮");
        WaitForDialogRootOrFail(app, new[] { "删除角色", roleSeed.RoleName, "删除后不可恢复" }, TimeSpan.FromSeconds(15), "删除角色确认弹窗");
        ClickDialogButton(app, new[] { "删除角色", roleSeed.RoleName, "删除后不可恢复" }, "删除", "删除角色确认按钮");
        AssertFilteredRowEventuallyDisappears(app, roleSeed.RoleName, TimeSpan.FromSeconds(25), "角色管理删除结果");
    }

    [TestMethod]
    public void T27_审计日志可进入并显示关键区域()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        LoginAndWaitForShell(app);
        OpenUserModule(app);

        SelectUserModuleTab(app, "审计日志", new[] { "审计日志", "操作时间", "操作人", "查询" });
        AssertAnyNamedElementVisible(app, new[] { "审计日志", "操作时间", "操作人", "查询", "选择时间范围" }, TimeSpan.FromSeconds(25), "审计日志关键区域");
    }

    [TestMethod]
    public void T27_功能权限配置可进入并显示关键区域()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        LoginAndWaitForShell(app);
        OpenUserModule(app);

        SelectUserModuleTab(app, "功能权限配置", new[] { "功能权限配置主区域", "功能权限配置保存按钮", "功能权限配置", "模块", "保存", "角色" });
        AssertAnyNamedElementVisible(app, new[] { "功能权限配置主区域", "功能权限配置保存按钮", "功能权限配置", "模块", "保存", "角色" }, TimeSpan.FromSeconds(25), "功能权限配置关键区域");
    }

    [TestMethod]
    public void T22_用户管理打开目标用户操作菜单后应支持键盘交互()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        var targetUsername = MesUserModuleSeedHelper.CreateDisableTargetUser(TestContext);

        LoginAndWaitForShell(app);
        OpenUserModule(app);
        SelectUserModuleTab(app, "用户管理", new[] { "按账号搜索", "查询用户", "操作" });
        FillAnyTextBoxByNames(app, new[] { "按账号搜索", "账号", "用户名" }, targetUsername, submit: true, "用户管理账号筛选框");
        TryClickAnyNamedInteractiveElement(app, new[] { "查询用户", "搜索", "查询" }, "用户管理查询按钮");
        AssertElementContainingTextVisible(app, targetUsername, TimeSpan.FromSeconds(25), "目标用户行");

        var rowActionButton = FindRowButtonNearTextElement(app, targetUsername, "操作. 显示菜单")
            ?? FindRowButtonNearTextElement(app, targetUsername, "操作");
        Assert.IsNotNull(rowActionButton, $"未找到目标用户行操作控件：{targetUsername}");

        rowActionButton.Click();
        Thread.Sleep(500);
        var menuOpened = WaitForPopupWindow(app, TimeSpan.FromSeconds(5)) is not null;

        if (TryOpenDisableDialogViaKeyboardFallback(app, rowActionButton, targetUsername))
        {
            Keyboard.Type(VirtualKeyShort.ESCAPE);
            return;
        }

        Keyboard.Type(VirtualKeyShort.DOWN);
        Thread.Sleep(300);
        Keyboard.Type(VirtualKeyShort.ESCAPE);
        Assert.IsTrue(menuOpened, $"已点击目标用户操作控件，但未稳定观察到可交互的操作菜单。{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 3)}");
    }

    [TestMethod]
    public void T22_注册审批翻到目标页后驳回应提示成功()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        var rejectSeed = MesUserModuleSeedHelper.CreateRegistrationRejectSeed(TestContext);

        LoginAndWaitForShell(app);
        OpenUserModule(app);
        SelectUserModuleTab(app, "注册审批", new[] { "申请状态", "下一页", "用户名" });
        var rejectButton = WaitForNamedButton(app, "驳回", TimeSpan.FromSeconds(25), "注册申请驳回按钮");

        rejectButton.Click();
        Thread.Sleep(500);
        var rejectDialog = WaitForDialogRootOrFail(app, new[] { "驳回注册申请", "确认驳回账号", "驳回原因（可选）" }, TimeSpan.FromSeconds(15), "驳回确认弹窗");
        var rejectAccount = TryExtractRegistrationAccountFromDialog(rejectDialog) ?? rejectSeed.Account;

        FillTextBoxInRootByName(rejectDialog, "驳回原因（可选）", "FlaUI 边角回归", submit: false);
        ClickDialogButton(app, new[] { "驳回注册申请", "确认驳回账号", "驳回原因（可选）" }, "驳回", "驳回确认按钮");
        AssertRegistrationRejectSucceeded(app, rejectAccount);
    }

    [TestMethod]
    public void Probe_用户管理_行内操作菜单_UIA()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        var targetUsername = MesUserModuleSeedHelper.CreateDisableTargetUser(TestContext);

        LoginAndWaitForShell(app);
        OpenUserModule(app);
        SelectUserModuleTab(app, "用户管理", new[] { "按账号搜索", "查询用户", "操作" });
        FillAnyTextBoxByNames(app, new[] { "按账号搜索", "账号", "用户名" }, targetUsername, submit: true, "用户管理账号筛选框");
        TryClickAnyNamedInteractiveElement(app, new[] { "查询用户", "搜索", "查询" }, "用户管理查询按钮");
        AssertAnyNamedElementVisible(app, new[] { targetUsername }, TimeSpan.FromSeconds(25), "目标用户行");

        LogProbeElements(app, "用户管理页关键候选（点击操作前）", item =>
            item.ControlType == ControlType.Edit
            || item.ControlType == ControlType.Button
            || item.ControlType == ControlType.TabItem
            || item.ControlType == ControlType.Text
            || item.ControlType == ControlType.MenuItem
            || NameContainsAny(item, targetUsername, "按账号搜索", "账号", "用户名", "查询用户", "搜索", "查询", "操作", "停用"));

        var rowAnchor = FindElementsAcrossWindows(app, item =>
                !string.IsNullOrWhiteSpace(GetElementName(item))
                && (string.Equals(GetElementName(item), targetUsername, StringComparison.Ordinal) || GetElementName(item).Contains(targetUsername, StringComparison.Ordinal)))
            .OrderBy(item => string.Equals(GetElementName(item), targetUsername, StringComparison.Ordinal) ? 0 : 1)
            .ThenBy(item => item.ControlType == ControlType.Text ? 0 : item.ControlType == ControlType.Custom ? 1 : 2)
            .FirstOrDefault();
        Assert.IsNotNull(rowAnchor, $"未找到目标用户行锚点：{targetUsername}");
        TestContext.WriteLine($"[Probe] 用户管理行锚点：{UiTreeDebugHelper.DescribeElement(rowAnchor)}");
        TestContext.WriteLine($"[Probe] 用户管理行锚点祖先链：{Environment.NewLine}{UiTreeDebugHelper.DumpAncestors(app.Automation, rowAnchor)}");

        var rowActionButton = FindRowButtonNearTextElement(app, rowAnchor, "操作");
        Assert.IsNotNull(rowActionButton, $"未找到目标用户行操作控件。{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 4)}");
        TestContext.WriteLine($"[Probe] 用户管理行操作控件：{UiTreeDebugHelper.DescribeElement(rowActionButton)}");
        TestContext.WriteLine($"[Probe] 用户管理行操作控件祖先链：{Environment.NewLine}{UiTreeDebugHelper.DumpAncestors(app.Automation, rowActionButton)}");

        rowActionButton.Click();
        Thread.Sleep(1000);

        TestContext.WriteLine($"[Probe] 点击操作后顶层窗口总览：{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 2)}");
        LogProbeElements(app, "用户管理操作菜单候选（点击操作后）", item =>
            item.ControlType == ControlType.MenuItem
            || item.ControlType == ControlType.Button
            || item.ControlType == ControlType.Text
            || item.ControlType == ControlType.Custom
            || NameContainsAny(item, targetUsername, "停用", "启用", "重置密码", "操作"));

        var disableCandidate = EnumeratePopupFirstSearchRoots(app)
            .SelectMany(root => root.FindAllDescendants().Prepend(root))
            .FirstOrDefault(item =>
                (item.ControlType == ControlType.MenuItem || item.ControlType == ControlType.Button || item.ControlType == ControlType.Text || item.ControlType == ControlType.Custom)
                && GetElementName(item).Contains("停用", StringComparison.Ordinal));
        if (disableCandidate is not null)
        {
            TestContext.WriteLine($"[Probe] 用户管理停用候选：{UiTreeDebugHelper.DescribeElement(disableCandidate)}");
            TestContext.WriteLine($"[Probe] 用户管理停用候选祖先链：{Environment.NewLine}{UiTreeDebugHelper.DumpAncestors(app.Automation, disableCandidate)}");
        }
        else
        {
            TestContext.WriteLine("[Probe] 点击操作后未捕获到名称包含“停用”的候选控件。可能菜单项未暴露 Name，或动作菜单并非标准独立项。\n"
                + UiTreeDebugHelper.DumpMatchesByRoot(app, item =>
                    item.ControlType == ControlType.MenuItem
                    || item.ControlType == ControlType.Button
                    || item.ControlType == ControlType.Text
                    || item.ControlType == ControlType.Custom,
                    limitPerRoot: 80));
        }
    }

    [TestMethod]
    public void Probe_注册审批_筛选与驳回_UIA()
    {
        using var app = MesAppDriver.Launch(withBackend: true, TestContext);
        var rejectSeed = MesUserModuleSeedHelper.CreateRegistrationRejectSeed(TestContext);

        LoginAndWaitForShell(app);
        OpenUserModule(app);
        ClickNamedInteractiveElement(app, "注册审批", "注册审批页签");
        AssertAnyNamedElementVisible(app, new[] { "申请状态", "用户名", "待审批" }, TimeSpan.FromSeconds(25), "注册审批关键筛选或表头");

        LogProbeElements(app, "注册审批页筛选区候选（进入页面后）", item =>
            item.ControlType == ControlType.Edit
            || item.ControlType == ControlType.ComboBox
            || item.ControlType == ControlType.Button
            || item.ControlType == ControlType.Text
            || NameContainsAny(item, "申请状态", "用户名", "账号", "待审批", "查询", "搜索", "筛选"));

        var usernameTextBox = FindTextBoxAcrossWindows(app, "用户名") ?? FindTextBoxAcrossWindows(app, "账号");
        var targetAccountForReject = rejectSeed.Account;
        if (usernameTextBox is not null)
        {
            TestContext.WriteLine($"[Probe] 注册审批用户名筛选输入：{UiTreeDebugHelper.DescribeElement(usernameTextBox)}");
            TestContext.WriteLine($"[Probe] 注册审批用户名筛选输入祖先链：{Environment.NewLine}{UiTreeDebugHelper.DumpAncestors(app.Automation, usernameTextBox)}");

            FillAnyTextBoxByNames(app, new[] { "用户名", "账号" }, rejectSeed.Account, submit: true, "注册审批用户名筛选框");
            TryClickAnyNamedInteractiveElement(app, new[] { "查询", "搜索", "筛选" }, "注册审批查询按钮");
            AssertAnyNamedElementVisible(app, new[] { rejectSeed.Account }, TimeSpan.FromSeconds(25), "目标注册申请行");
        }
        else
        {
            TestContext.WriteLine("[Probe] 未直接找到名称为“用户名/账号”的 Edit 控件，将继续记录页面候选元素。\n"
                + UiTreeDebugHelper.DumpMatchesByRoot(app, item => item.ControlType == ControlType.Edit || item.ControlType == ControlType.ComboBox || item.ControlType == ControlType.Button || item.ControlType == ControlType.Text, 80));

            targetAccountForReject = FindElementsAcrossWindows(app, item => item.ControlType == ControlType.Text && !string.IsNullOrWhiteSpace(GetElementName(item)))
                .Select(GetElementName)
                .FirstOrDefault(name => name.Any(char.IsLetterOrDigit) && !name.Contains(':') && !name.Contains('第') && !name.Contains("注册审批") && !name.Contains("申请状态") && !name.Contains("驳回原因") && !name.Contains("待审批") && !name.Contains("通过") && !name.Contains("驳回"))
                ?? rejectSeed.Account;
            TestContext.WriteLine($"[Probe] 注册审批筛选输入缺失，回退为直接观察当前页可见驳回按钮。候选账号锚点={targetAccountForReject}");
        }

        var rejectButton = FindRowButtonNearTextElement(app, targetAccountForReject, "驳回")
            ?? FindElementsAcrossWindows(app, item => item.ControlType == ControlType.Button && string.Equals(GetElementName(item), "驳回", StringComparison.Ordinal)).FirstOrDefault();
        if (rejectButton is null)
        {
            TestContext.WriteLine("[Probe] 当前运行态未捕获到可点击的“驳回”按钮，无法继续观察确认弹层。\n"
                + UiTreeDebugHelper.DumpMatchesByRoot(app, item => item.ControlType == ControlType.Button || item.ControlType == ControlType.Text, 80));
            return;
        }
        TestContext.WriteLine($"[Probe] 注册审批驳回控件：{UiTreeDebugHelper.DescribeElement(rejectButton)}");
        TestContext.WriteLine($"[Probe] 注册审批驳回控件祖先链：{Environment.NewLine}{UiTreeDebugHelper.DumpAncestors(app.Automation, rejectButton)}");

        rejectButton.Click();
        Thread.Sleep(1000);

        TestContext.WriteLine($"[Probe] 点击驳回后顶层窗口总览：{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 2)}");
        LogProbeElements(app, "注册审批驳回弹层候选（点击驳回后）", item =>
            item.ControlType == ControlType.Window
            || item.ControlType == ControlType.Pane
            || item.ControlType == ControlType.Group
            || item.ControlType == ControlType.Custom
            || item.ControlType == ControlType.Button
            || item.ControlType == ControlType.Edit
            || item.ControlType == ControlType.Text
            || NameContainsAny(item, "驳回", "驳回注册申请", targetAccountForReject, "驳回原因"));

        var dialogRoot = FindDialogRoot(app, new[] { "驳回", targetAccountForReject });
        if (dialogRoot is not null)
        {
            TestContext.WriteLine($"[Probe] 注册审批驳回弹层根：{UiTreeDebugHelper.DescribeElement(dialogRoot)}");
            TestContext.WriteLine($"[Probe] 注册审批驳回弹层根祖先链：{Environment.NewLine}{UiTreeDebugHelper.DumpAncestors(app.Automation, dialogRoot)}");
            TestContext.WriteLine($"[Probe] 注册审批驳回弹层局部子树：{Environment.NewLine}{UiTreeDebugHelper.DumpSubtree(dialogRoot, 3)}");
        }
        else
        {
            TestContext.WriteLine("[Probe] 点击驳回后未定位到包含“驳回/账号”的弹层根节点，可能对话框未以独立可命名容器暴露。\n"
                + UiTreeDebugHelper.DumpMatchesByRoot(app, item =>
                    item.ControlType == ControlType.Window
                    || item.ControlType == ControlType.Pane
                    || item.ControlType == ControlType.Group
                    || item.ControlType == ControlType.Custom
                    || item.ControlType == ControlType.Button
                    || item.ControlType == ControlType.Edit
                    || item.ControlType == ControlType.Text,
                    limitPerRoot: 80));
        }
    }

    private static bool HasAnyNamedElement(MesAppDriver app, IEnumerable<string> names)
    {
        foreach (var name in names)
        {
            if (app.FindByName(name) is not null)
            {
                return true;
            }
        }

        return false;
    }

    private void LogProbeElements(MesAppDriver app, string title, Func<AutomationElement, bool> predicate)
    {
        TestContext.WriteLine($"[Probe] {title}:{Environment.NewLine}{UiTreeDebugHelper.DumpMatchesByRoot(app, predicate, 80)}");
    }

    private static bool NameContainsAny(AutomationElement element, params string[] candidates)
    {
        var name = GetElementName(element);
        return candidates.Any(candidate => !string.IsNullOrWhiteSpace(candidate) && name.Contains(candidate, StringComparison.Ordinal));
    }

    private static bool HasElementContainingText(MesAppDriver app, string text)
    {
        return FindElementsAcrossWindows(app, item => GetElementName(item).Contains(text, StringComparison.Ordinal)).Count > 0;
    }

    private static void AssertElementContainingTextVisible(MesAppDriver app, string text, TimeSpan timeout, string description)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            if (HasElementContainingText(app, text))
            {
                return;
            }

            Thread.Sleep(500);
        }

        throw new AssertFailedException($"在超时内未看到 {description}。目标文本：{text}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 3)}");
    }

    private static void AssertFilteredRowEventuallyDisappears(MesAppDriver app, string text, TimeSpan timeout, string description)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            if (!HasElementContainingText(app, text) || HasAnyNamedElement(app, new[] { "暂无在线会话", "暂无角色数据" }))
            {
                return;
            }

            TryActivateAnyNamedInteractiveElement(app, new[] { "查询", "搜索", "刷新" }, $"{description}刷新操作");

            Thread.Sleep(500);
        }

        throw new AssertFailedException($"在超时内未观察到 {description} 完成。目标文本仍存在：{text}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 4)}");
    }

    private AutomationElement? FindRowButtonNearTextElement(MesAppDriver app, string anchorText, string buttonName)
    {
        var anchor = FindElementsAcrossWindows(app, item =>
                !string.IsNullOrWhiteSpace(GetElementName(item))
                && (string.Equals(GetElementName(item), anchorText, StringComparison.Ordinal) || GetElementName(item).Contains(anchorText, StringComparison.Ordinal)))
            .OrderBy(item => string.Equals(GetElementName(item), anchorText, StringComparison.Ordinal) ? 0 : 1)
            .ThenBy(item => item.ControlType == ControlType.Text ? 0 : item.ControlType == ControlType.Custom ? 1 : 2)
            .FirstOrDefault();
        return anchor is null ? null : FindRowButtonNearTextElement(app, anchor, buttonName);
    }

    private AutomationElement? FindRowButtonNearTextElement(MesAppDriver app, AutomationElement anchor, string buttonName)
    {
        var walker = app.Automation.TreeWalkerFactory.GetControlViewWalker();
        var parent = walker.GetParent(anchor);
        while (parent is not null)
        {
            var button = parent
                .FindAllDescendants()
                .OrderBy(item => item.ControlType == ControlType.Button ? 0 : item.ControlType == ControlType.Hyperlink ? 1 : item.ControlType == ControlType.Text ? 2 : 3)
                .FirstOrDefault(item =>
                    (item.ControlType == ControlType.Button || item.ControlType == ControlType.Hyperlink || item.ControlType == ControlType.Text)
                    && (string.Equals(GetElementName(item), buttonName, StringComparison.Ordinal) || GetElementName(item).Contains(buttonName, StringComparison.Ordinal)));
            if (button is not null)
            {
                return button;
            }

            parent = walker.GetParent(parent);
        }

        return null;
    }

    private static AutomationElement? FindNamedInteractiveElement(MesAppDriver app, string exactName)
    {
        var matches = FindElementsAcrossWindows(app, item => GetElementName(item).Contains(exactName, StringComparison.Ordinal));

        return matches.FirstOrDefault(item => item.ControlType == ControlType.TabItem)
            ?? matches.FirstOrDefault(item => item.ControlType == ControlType.Button)
            ?? matches.FirstOrDefault(item => item.ControlType == ControlType.MenuItem)
            ?? matches.FirstOrDefault(item => item.ControlType == ControlType.Hyperlink)
            ?? matches.FirstOrDefault(item => item.ControlType == ControlType.Text)
            ?? matches.FirstOrDefault();
    }

    private static bool TryActivateAnyNamedInteractiveElement(MesAppDriver app, IEnumerable<string> names, string description)
    {
        foreach (var name in names)
        {
            var target = FindNamedInteractiveElement(app, name);
            if (target is null)
            {
                continue;
            }

            ActivateInteractiveElement(target, description);
            return true;
        }

        return false;
    }

    private static void ClickNamedInteractiveElement(MesAppDriver app, string exactName, string description)
    {
        var target = FindNamedInteractiveElement(app, exactName);
        Assert.IsNotNull(target, $"未找到可点击元素：{description}");
        ActivateInteractiveElement(target, description);
    }

    private static void ClickNamedMenuItem(MesAppDriver app, string exactName, string description)
    {
        var deadline = DateTime.UtcNow + TimeSpan.FromSeconds(10);
        while (DateTime.UtcNow < deadline)
        {
            var target = EnumeratePopupFirstSearchRoots(app)
                .SelectMany(root => root.FindAllDescendants().Prepend(root))
                .Where(item => item.ControlType == ControlType.MenuItem || item.ControlType == ControlType.Button || item.ControlType == ControlType.Text)
                .Where(item => string.Equals(GetElementName(item), exactName, StringComparison.Ordinal) || GetElementName(item).Contains(exactName, StringComparison.Ordinal))
                .OrderBy(item => item.ControlType == ControlType.MenuItem ? 0 : item.ControlType == ControlType.Button ? 1 : 2)
                .FirstOrDefault();
            if (target is not null)
            {
                target.Click();
                Thread.Sleep(500);
                return;
            }

            Thread.Sleep(300);
        }

        Assert.Fail($"未找到菜单项：{description}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 3)}");
    }

    private static Window? WaitForPopupWindow(MesAppDriver app, TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            var popupWindow = app.GetAllTopLevelWindows()
                .FirstOrDefault(window => !ReferenceEquals(window, app.MainWindow));
            if (popupWindow is not null)
            {
                return popupWindow;
            }

            Thread.Sleep(200);
        }

        return null;
    }

    private static bool TryOpenDisableDialogViaKeyboardFallback(MesAppDriver app, AutomationElement rowActionButton, string targetUsername)
    {
        var sequences = new[]
        {
            Array.Empty<VirtualKeyShort>(),
            new[] { VirtualKeyShort.DOWN },
            new[] { VirtualKeyShort.HOME },
            new[] { VirtualKeyShort.DOWN, VirtualKeyShort.DOWN },
        };

        foreach (var sequence in sequences)
        {
            rowActionButton.Click();
            Thread.Sleep(500);

            foreach (var key in sequence)
            {
                Keyboard.Type(key);
                Thread.Sleep(200);
            }

            Keyboard.Type(VirtualKeyShort.ENTER);
            Thread.Sleep(800);
            if (FindDialogRoot(app, new[] { "停用用户", "确认停用用户", targetUsername }) is not null)
            {
                return true;
            }

            Keyboard.Type(VirtualKeyShort.ESCAPE);
            Thread.Sleep(300);
        }

        return false;
    }

    private static void FillTextBoxByName(MesAppDriver app, string textBoxName, string value, bool submit)
    {
        var textBox = FindTextBoxAcrossWindows(app, textBoxName);
        Assert.IsNotNull(textBox, $"未找到文本框：{textBoxName}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 4)}");
        FillTextBox(textBox, value, submit);
    }

    private static void FillTextBoxInRootByName(AutomationElement root, string textBoxName, string value, bool submit)
    {
        var textBox = root
            .FindAllDescendants()
            .Prepend(root)
            .Where(item => item.ControlType == ControlType.Edit)
            .Where(item => string.Equals(GetElementName(item), textBoxName, StringComparison.Ordinal) || GetElementName(item).Contains(textBoxName, StringComparison.Ordinal))
            .Select(item =>
            {
                try
                {
                    return item.AsTextBox();
                }
                catch
                {
                    return null;
                }
            })
            .FirstOrDefault(static item => item is not null);
        Assert.IsNotNull(textBox, $"未在对话框内找到文本框：{textBoxName}{Environment.NewLine}{UiTreeDebugHelper.DumpSubtree(root, 4)}");
        FillTextBox(textBox, value, submit);
    }

    private static void ClickRowButtonNearText(MesAppDriver app, string anchorText, string buttonName, string description)
    {
        var anchor = FindElementsAcrossWindows(app, item =>
                !string.IsNullOrWhiteSpace(GetElementName(item))
                && (string.Equals(GetElementName(item), anchorText, StringComparison.Ordinal) || GetElementName(item).Contains(anchorText, StringComparison.Ordinal)))
            .OrderBy(item => string.Equals(GetElementName(item), anchorText, StringComparison.Ordinal) ? 0 : 1)
            .ThenBy(item => item.ControlType == ControlType.Text ? 0 : item.ControlType == ControlType.Custom ? 1 : 2)
            .FirstOrDefault();
        Assert.IsNotNull(anchor, $"未找到行锚点文本：{anchorText}");

        var walker = app.Automation.TreeWalkerFactory.GetControlViewWalker();
        var parent = walker.GetParent(anchor);
        while (parent is not null)
        {
            var button = parent
                .FindAllDescendants()
                .OrderBy(item => item.ControlType == ControlType.Button ? 0 : item.ControlType == ControlType.Hyperlink ? 1 : item.ControlType == ControlType.Text ? 2 : 3)
                .FirstOrDefault(item =>
                    (item.ControlType == ControlType.Button || item.ControlType == ControlType.Hyperlink || item.ControlType == ControlType.Text)
                    && (string.Equals(GetElementName(item), buttonName, StringComparison.Ordinal) || GetElementName(item).Contains(buttonName, StringComparison.Ordinal)));
            if (button is not null)
            {
                ActivateInteractiveElement(button, description);
                return;
            }

            parent = walker.GetParent(parent);
        }

        Assert.Fail($"未找到按钮：{description}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 5)}");
    }

    private static void FillAnyTextBoxByNames(MesAppDriver app, IEnumerable<string> textBoxNames, string value, bool submit, string description)
    {
        foreach (var textBoxName in textBoxNames)
        {
            var textBox = FindTextBoxAcrossWindows(app, textBoxName);
            if (textBox is null)
            {
                continue;
            }

            FillTextBox(textBox, value, submit);
            return;
        }

        Assert.Fail($"未找到文本框：{description}。候选文本：{string.Join('、', textBoxNames)}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 4)}");
    }

    private static TextBox? FindTextBoxAcrossWindows(MesAppDriver app, string textBoxName)
    {
        return FindElementsAcrossWindows(app, item =>
                item.ControlType == ControlType.Edit
                && (string.Equals(GetElementName(item), textBoxName, StringComparison.Ordinal) || GetElementName(item).Contains(textBoxName, StringComparison.Ordinal)))
            .OrderBy(item => string.Equals(GetElementName(item), textBoxName, StringComparison.Ordinal) ? 0 : 1)
            .Select(item =>
            {
                try
                {
                    return item.AsTextBox();
                }
                catch
                {
                    return null;
                }
            })
            .FirstOrDefault(static item => item is not null);
    }

    private static void FillTextBox(TextBox textBox, string value, bool submit)
    {
        textBox.Click();
        textBox.Focus();
        Thread.Sleep(200);
        Keyboard.TypeSimultaneously(VirtualKeyShort.CONTROL, VirtualKeyShort.KEY_A);
        Thread.Sleep(100);
        Keyboard.Type(VirtualKeyShort.DELETE);
        Thread.Sleep(100);
        Keyboard.Type(value);

        Thread.Sleep(300);
        if (submit)
        {
            Keyboard.Type(VirtualKeyShort.ENTER);
            Thread.Sleep(300);
        }
    }

    private static AutomationElement WaitForNamedButton(MesAppDriver app, string buttonName, TimeSpan timeout, string description)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            var button = FindElementsAcrossWindows(app, item => item.ControlType == ControlType.Button && string.Equals(GetElementName(item), buttonName, StringComparison.Ordinal))
                .FirstOrDefault();
            if (button is not null)
            {
                return button;
            }

            Thread.Sleep(300);
        }

        throw new AssertFailedException($"未找到按钮：{description}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 4)}");
    }

    private void TryClickAnyNamedInteractiveElement(MesAppDriver app, IEnumerable<string> names, string description)
    {
        foreach (var name in names)
        {
            var target = FindNamedInteractiveElement(app, name);
            if (target is null)
            {
                continue;
            }

            TestContext.WriteLine($"点击 {description}：Name={GetElementName(target)}，Type={target.ControlType}");
            target.Click();
            Thread.Sleep(500);
            return;
        }
    }

    private void ClickDialogButton(MesAppDriver app, IEnumerable<string> dialogWitnesses, string buttonName, string description)
    {
        var deadline = DateTime.UtcNow + TimeSpan.FromSeconds(15);
        while (DateTime.UtcNow < deadline)
        {
            var dialogRoot = FindDialogRoot(app, dialogWitnesses);
            if (dialogRoot is not null)
            {
                var target = dialogRoot
                    .FindAllDescendants()
                    .Prepend(dialogRoot)
                    .Where(item => item.ControlType == ControlType.Button || item.ControlType == ControlType.MenuItem || item.ControlType == ControlType.Text)
                    .Where(item => string.Equals(GetElementName(item), buttonName, StringComparison.Ordinal) || GetElementName(item).Contains(buttonName, StringComparison.Ordinal))
                    .OrderBy(item => item.ControlType == ControlType.Button ? 0 : item.ControlType == ControlType.MenuItem ? 1 : 2)
                    .FirstOrDefault();
                if (target is not null)
                {
                    target.Click();
                    Thread.Sleep(500);
                    return;
                }
            }

            Thread.Sleep(300);
        }

        Assert.Fail($"未找到对话框按钮：{description}。对话框特征：{string.Join('、', dialogWitnesses)}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 4)}");
    }

    private void AssertRegistrationRejectSucceeded(MesAppDriver app, string account)
    {
        var deadline = DateTime.UtcNow + TimeSpan.FromSeconds(25);
        while (DateTime.UtcNow < deadline)
        {
            if (HasElementContainingText(app, $"已驳回账号 {account} 的注册申请")
                || HasElementContainingText(app, "已驳回账号")
                || HasElementContainingText(app, "已驳回")
                || RegistrationRowContainsStatus(app, account, "已驳回"))
            {
                return;
            }

            Thread.Sleep(500);
        }

        throw new AssertFailedException($"未观察到注册审批驳回成功反馈。目标账号：{account}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 4)}");
    }

    private static string? TryExtractRegistrationAccountFromDialog(AutomationElement dialogRoot)
    {
        var message = dialogRoot
            .FindAllDescendants()
            .Prepend(dialogRoot)
            .Select(GetElementName)
            .FirstOrDefault(name => name.Contains("确认驳回账号", StringComparison.Ordinal));
        if (string.IsNullOrWhiteSpace(message))
        {
            return null;
        }

        var match = Regex.Match(message, "确认驳回账号[\\\"”](?<account>[A-Za-z0-9_]+)[\\\"”]的注册申请吗？");
        return match.Success ? match.Groups["account"].Value : null;
    }

    private bool RegistrationRowContainsStatus(MesAppDriver app, string account, string statusText)
    {
        var anchor = FindElementsAcrossWindows(app, item =>
                !string.IsNullOrWhiteSpace(GetElementName(item))
                && (string.Equals(GetElementName(item), account, StringComparison.Ordinal) || GetElementName(item).Contains(account, StringComparison.Ordinal)))
            .OrderBy(item => string.Equals(GetElementName(item), account, StringComparison.Ordinal) ? 0 : 1)
            .ThenBy(item => item.ControlType == ControlType.Text ? 0 : item.ControlType == ControlType.Custom ? 1 : 2)
            .FirstOrDefault();
        if (anchor is null)
        {
            return false;
        }

        var walker = app.Automation.TreeWalkerFactory.GetControlViewWalker();
        var parent = walker.GetParent(anchor);
        while (parent is not null)
        {
            if (ElementOrDescendantsContainText(parent, statusText))
            {
                return true;
            }

            parent = walker.GetParent(parent);
        }

        return false;
    }

    private static AutomationElement? FindDialogRoot(MesAppDriver app, IEnumerable<string> dialogWitnesses)
    {
        foreach (var root in EnumeratePopupFirstSearchRoots(app))
        {
            var candidates = root
                .FindAllDescendants()
                .Prepend(root)
                .Where(item => item.ControlType == ControlType.Window || item.ControlType == ControlType.Pane || item.ControlType == ControlType.Group || item.ControlType == ControlType.Custom)
                .Where(item => dialogWitnesses.Any(witness => ElementOrDescendantsContainText(item, witness)))
                .ToList();
            if (candidates.Count > 0)
            {
                return candidates.First();
            }
        }

        return null;
    }

    private static AutomationElement WaitForDialogRootOrFail(MesAppDriver app, IEnumerable<string> dialogWitnesses, TimeSpan timeout, string description)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            var dialogRoot = FindDialogRoot(app, dialogWitnesses);
            if (dialogRoot is not null)
            {
                return dialogRoot;
            }

            Thread.Sleep(300);
        }

        throw new AssertFailedException($"未找到对话框：{description}。对话框特征：{string.Join('、', dialogWitnesses)}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 4)}");
    }

    private static bool ElementOrDescendantsContainText(AutomationElement root, string text)
    {
        if (GetElementName(root).Contains(text, StringComparison.Ordinal))
        {
            return true;
        }

        return root.FindAllDescendants().Any(item => GetElementName(item).Contains(text, StringComparison.Ordinal));
    }

    private void SelectUserModuleTab(MesAppDriver app, string tabName, IEnumerable<string> pageWitnesses)
    {
        var witnesses = pageWitnesses.ToArray();
        if (TrySelectUserModuleTabDirectly(app, tabName, witnesses))
        {
            return;
        }

        if (TrySelectUserModuleTabByKeyboardFallback(app, tabName, witnesses))
        {
            return;
        }

        throw new AssertFailedException($"点击页签 {tabName} 后未看到页面特征，键盘切页兜底也未生效。候选文本：{string.Join('、', witnesses)}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 5)}");
    }

    private static AutomationElement? FindMessageEntry(MesAppDriver app)
    {
        return app.MainWindow
            .FindAllDescendants()
            .FirstOrDefault(static item => item.ControlType == ControlType.Button && !string.IsNullOrWhiteSpace(item.Name) && item.Name.Contains("消息", StringComparison.Ordinal));
    }

    private void LoginAndWaitForShell(MesAppDriver app)
    {
        MesLoginHelper.LoginAsAdmin(app);
        MesLoginHelper.WaitForShellReady(app, TimeSpan.FromSeconds(60), TestContext.WriteLine);
        WaitForUserNavigationVisible(app, TimeSpan.FromSeconds(45));
    }

    private void OpenUserModule(MesAppDriver app)
    {
        TryFocusMainWindow(app);
        AssertAnyNamedElementVisible(app, new[] { "用户" }, TimeSpan.FromSeconds(20), "用户导航");
        var userEntry = FindNamedNavigationElement(app, "用户");
        Assert.IsNotNull(userEntry, $"主壳层未找到用户模块导航元素。{UiTreeDebugHelper.DumpAllWindows(app, 3)}");
        TestContext.WriteLine($"点击用户导航：Name={userEntry.Name}，Type={userEntry.ControlType}");
        userEntry.Click();

        AssertAnyNamedElementVisible(app, UserModuleTabCandidates, TimeSpan.FromSeconds(60), "用户模块页签");
    }

    private static void TryFocusMainWindow(MesAppDriver app)
    {
        try
        {
            app.MainWindow.Focus();
            Thread.Sleep(300);
        }
        catch
        {
        }
    }

    private void WaitForUserNavigationVisible(MesAppDriver app, TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        DateTime? shellLandmarkSeenAt = null;
        var shellLandmarkCandidates = new[] { "产品", "工艺", "生产", "设备", "质量", "品质", "消息" };

        while (DateTime.UtcNow < deadline)
        {
            TryFocusMainWindow(app);
            if (FindNamedNavigationElement(app, "用户") is not null)
            {
                return;
            }

            foreach (var window in app.GetAllTopLevelWindows())
            {
                if (ReferenceEquals(window, app.MainWindow))
                {
                    continue;
                }

                try
                {
                    window.Focus();
                    Thread.Sleep(150);
                }
                catch
                {
                }

                if (FindNamedNavigationElement(app, "用户") is not null)
                {
                    TryFocusMainWindow(app);
                    return;
                }
            }

            TryFocusMainWindow(app);
            if (shellLandmarkSeenAt is null && shellLandmarkCandidates.Any(candidate => FindNamedNavigationElement(app, candidate) is not null))
            {
                shellLandmarkSeenAt = DateTime.UtcNow;
                TestContext.WriteLine("已观测到主壳层稳定导航，继续短暂等待用户入口暴露。");
            }

            if (shellLandmarkSeenAt is not null && DateTime.UtcNow - shellLandmarkSeenAt.Value >= TimeSpan.FromSeconds(6))
            {
                break;
            }

            Thread.Sleep(500);
        }

        throw new AssertFailedException($"在超时内未看到 用户导航。{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 3)}");
    }

    private bool EnsureUserModulePageVisible(MesAppDriver app, string tabName, IEnumerable<string> pageWitnesses, bool allowWitnessWithoutTabClick)
    {
        var witnesses = pageWitnesses.ToArray();
        if (allowWitnessWithoutTabClick && HasAnyNamedElement(app, witnesses))
        {
            TestContext.WriteLine($"用户模块打开后已直接命中 {tabName} 页面特征，无需再次点击页签。");
            return true;
        }

        if (TrySelectUserModuleTabDirectly(app, tabName, witnesses))
        {
            return true;
        }

        return TrySelectUserModuleTabByKeyboardFallback(app, tabName, witnesses);
    }

    private bool TrySelectUserModuleTabDirectly(MesAppDriver app, string tabName, IReadOnlyCollection<string> pageWitnesses)
    {
        var candidates = FindUserModuleTabCandidates(app, tabName);
        if (candidates.Count == 0)
        {
            TestContext.WriteLine($"未直接找到页签候选：{tabName}");
            return false;
        }

        foreach (var candidate in candidates)
        {
            ActivateInteractiveElement(candidate, $"{tabName}页签");
            if (WaitForAnyNamedElementVisible(app, pageWitnesses, TimeSpan.FromSeconds(4)))
            {
                return true;
            }
        }

        return false;
    }

    private bool TrySelectUserModuleTabByKeyboardFallback(MesAppDriver app, string tabName, IReadOnlyCollection<string> pageWitnesses)
    {
        foreach (var anchorTab in GetKeyboardFallbackAnchors(tabName))
        {
            var anchorWitnesses = GetUserModuleTabWitnesses(anchorTab);
            if (!TrySelectUserModuleTabDirectly(app, anchorTab, anchorWitnesses))
            {
                continue;
            }

            var anchorElement = FindUserModuleTabCandidates(app, anchorTab).FirstOrDefault();
            if (anchorElement is null)
            {
                TestContext.WriteLine($"键盘兜底未找到锚点页签元素：{anchorTab}");
                continue;
            }

            TryFocusElement(anchorElement);
            Thread.Sleep(250);

            var stepCount = GetRightWrapStepCount(anchorTab, tabName);
            TestContext.WriteLine($"开始键盘切页兜底：锚点={anchorTab}，目标={tabName}，右移步数={stepCount}");
            if (stepCount == 0 && HasAnyNamedElement(app, pageWitnesses))
            {
                return true;
            }

            for (var step = 0; step < stepCount; step++)
            {
                Keyboard.Type(VirtualKeyShort.RIGHT);
                Thread.Sleep(300);
                Keyboard.Type(VirtualKeyShort.ENTER);
                if (WaitForAnyNamedElementVisible(app, pageWitnesses, TimeSpan.FromSeconds(3)))
                {
                    TestContext.WriteLine($"键盘切页命中目标页面：目标={tabName}，完成步数={step + 1}");
                    return true;
                }

                Keyboard.Type(VirtualKeyShort.SPACE);
                if (WaitForAnyNamedElementVisible(app, pageWitnesses, TimeSpan.FromSeconds(2)))
                {
                    TestContext.WriteLine($"键盘切页命中目标页面：目标={tabName}，完成步数={step + 1}，激活方式=Space");
                    return true;
                }
            }
        }

        return false;
    }

    private static List<AutomationElement> FindUserModuleTabCandidates(MesAppDriver app, string tabName)
    {
        return app.MainWindow
            .FindAllDescendants()
            .Where(item => GetElementName(item).Contains(tabName, StringComparison.Ordinal))
            .OrderBy(item => item.ControlType == ControlType.TabItem ? 0 : item.ControlType == ControlType.Button ? 1 : item.ControlType == ControlType.Text ? 2 : 3)
            .ToList();
    }

    private static void TryFocusElement(AutomationElement element)
    {
        try
        {
            element.Focus();
            return;
        }
        catch
        {
        }

        try
        {
            element.Click();
        }
        catch
        {
        }
    }

    private static void ActivateInteractiveElement(AutomationElement element, string description)
    {
        TryScrollIntoView(element);
        TryFocusElement(element);

        try
        {
            element.Click();
            Thread.Sleep(500);
            return;
        }
        catch (NoClickablePointException)
        {
        }
        catch
        {
        }

        try
        {
            var invokePattern = element.Patterns.Invoke.PatternOrDefault;
            if (invokePattern is not null)
            {
                invokePattern.Invoke();
                Thread.Sleep(500);
                return;
            }
        }
        catch
        {
        }

        TryFocusElement(element);
        Keyboard.Type(VirtualKeyShort.ENTER);
        Thread.Sleep(400);

        TryFocusElement(element);
        Keyboard.Type(VirtualKeyShort.SPACE);
        Thread.Sleep(400);
    }

    private static void TryScrollIntoView(AutomationElement element)
    {
        try
        {
            var scrollItemPattern = element.Patterns.ScrollItem.PatternOrDefault;
            scrollItemPattern?.ScrollIntoView();
        }
        catch
        {
        }
    }

    private static IEnumerable<string> GetKeyboardFallbackAnchors(string targetTab)
    {
        var preferredAnchors = targetTab switch
        {
            "个人中心" => ["角色管理", "审计日志", "登录会话"],
            "功能权限配置" => ["登录会话", "个人中心", "审计日志"],
            _ => Array.Empty<string>()
        };

        foreach (var anchor in preferredAnchors)
        {
            if (!string.Equals(anchor, targetTab, StringComparison.Ordinal))
            {
                yield return anchor;
            }
        }

        foreach (var anchor in UserModuleTabCandidates)
        {
            if (!string.Equals(anchor, targetTab, StringComparison.Ordinal) && !preferredAnchors.Contains(anchor, StringComparer.Ordinal))
            {
                yield return anchor;
            }
        }
    }

    private static int GetRightWrapStepCount(string anchorTab, string targetTab)
    {
        var anchorIndex = Array.IndexOf(UserModuleTabCandidates, anchorTab);
        var targetIndex = Array.IndexOf(UserModuleTabCandidates, targetTab);
        if (anchorIndex < 0 || targetIndex < 0)
        {
            return UserModuleTabCandidates.Length;
        }

        return (targetIndex - anchorIndex + UserModuleTabCandidates.Length) % UserModuleTabCandidates.Length;
    }

    private static string[] GetUserModuleTabWitnesses(string tabName)
    {
        return tabName switch
        {
            "用户管理" => ["角色管理", "账号", "角色", "状态"],
            "注册审批" => ["申请状态", "用户名", "待审批"],
            "角色管理" => ["角色名称", "新增角色", "关键词", "状态"],
            "审计日志" => ["审计日志", "操作时间", "操作人", "查询"],
            "个人中心" => ["个人中心主区域", "个人中心", "修改密码", "当前会话", "用户名"],
            "登录会话" => ["登录会话主区域", "登录会话筛选与操作区", "在线会话列表区域", "在线会话", "关键词", "强制下线", "用户名"],
            "功能权限配置" => ["功能权限配置主区域", "功能权限配置保存按钮", "功能权限配置", "模块", "保存", "角色"],
            _ => [tabName]
        };
    }

    private void AssertAnyNamedElementVisible(MesAppDriver app, IEnumerable<string> candidates, TimeSpan timeout, string description)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            foreach (var candidate in candidates)
            {
                if (FindNamedNavigationElement(app, candidate) is not null)
                {
                    return;
                }
            }

            Thread.Sleep(500);
        }

        throw new AssertFailedException($"在超时内未看到 {description}。候选文本：{string.Join('、', candidates)}{Environment.NewLine}{UiTreeDebugHelper.DumpAllWindows(app, 3)}");
    }

    private static bool WaitForAnyNamedElementVisible(MesAppDriver app, IEnumerable<string> candidates, TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            if (HasAnyNamedElement(app, candidates))
            {
                return true;
            }

            Thread.Sleep(250);
        }

        return false;
    }

    private static AutomationElement? FindNamedNavigationElement(MesAppDriver app, string nameFragment)
    {
        var descendants = FindElementsAcrossWindows(app, static _ => true);
        var exactMatches = descendants
            .Where(item => string.Equals(GetElementName(item), nameFragment, StringComparison.Ordinal))
            .ToList();
        if (exactMatches.Count > 0)
        {
            return exactMatches.FirstOrDefault(item => item.ControlType == ControlType.Button)
                ?? exactMatches.FirstOrDefault(item => item.ControlType == ControlType.ListItem)
                ?? exactMatches.FirstOrDefault(item => item.ControlType == ControlType.TabItem)
                ?? exactMatches.FirstOrDefault(item => item.ControlType == ControlType.Hyperlink)
                ?? exactMatches.FirstOrDefault(item => item.ControlType == ControlType.Text)
                ?? exactMatches.FirstOrDefault();
        }

        var fuzzyMatches = descendants
            .Where(item => GetElementName(item).Contains(nameFragment, StringComparison.Ordinal))
            .ToList();

        return fuzzyMatches.FirstOrDefault(item => item.ControlType == ControlType.Button)
            ?? fuzzyMatches.FirstOrDefault(item => item.ControlType == ControlType.ListItem)
            ?? fuzzyMatches.FirstOrDefault(item => item.ControlType == ControlType.TabItem)
            ?? fuzzyMatches.FirstOrDefault(item => item.ControlType == ControlType.Hyperlink)
            ?? fuzzyMatches.FirstOrDefault(item => item.ControlType == ControlType.Text)
            ?? fuzzyMatches.FirstOrDefault();
    }

    private static string GetElementName(AutomationElement element)
    {
        try
        {
            return element.Name ?? string.Empty;
        }
        catch (PropertyNotSupportedException)
        {
            return string.Empty;
        }
    }

    private static List<AutomationElement> FindElementsAcrossWindows(MesAppDriver app, Func<AutomationElement, bool> predicate)
    {
        var results = new List<AutomationElement>();
        foreach (var root in EnumerateSearchRoots(app))
        {
            if (predicate(root))
            {
                results.Add(root);
            }

            results.AddRange(root.FindAllDescendants().Where(predicate));
        }

        return results;
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

    private static IEnumerable<AutomationElement> EnumeratePopupFirstSearchRoots(MesAppDriver app)
    {
        foreach (var window in app.GetAllTopLevelWindows())
        {
            if (ReferenceEquals(window, app.MainWindow))
            {
                continue;
            }

            yield return window;
        }

        yield return app.MainWindow;
    }
}

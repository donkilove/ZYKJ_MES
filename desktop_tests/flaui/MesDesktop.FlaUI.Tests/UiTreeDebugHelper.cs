using System.Text;
using FlaUI.Core;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Exceptions;
using FlaUI.UIA3;

namespace MesDesktop.FlaUI.Tests;

internal static class UiTreeDebugHelper
{
    internal static string DescribeElement(AutomationElement element)
    {
        return $"Name=\"{GetProperty(() => element.Name)}\", Type={GetProperty(() => element.ControlType.ToString())}, AutomationId=\"{GetProperty(() => element.AutomationId)}\", Class=\"{GetProperty(() => element.ClassName)}\"";
    }

    internal static string DumpAllWindows(MesAppDriver app, int maxDepth = 4)
    {
        var builder = new StringBuilder();
        var windows = new List<Window> { app.MainWindow };
        windows.AddRange(app.GetAllTopLevelWindows().Where(window => !ReferenceEquals(window, app.MainWindow)));

        for (var index = 0; index < windows.Count; index++)
        {
            var window = windows[index];
            builder.AppendLine($"[TopLevelWindow #{index + 1}] Title=\"{GetProperty(() => window.Title)}\"");
            builder.AppendLine(DumpWindow(window, maxDepth));
        }

        return builder.ToString();
    }

    internal static string DumpWindow(Window window, int maxDepth = 4)
    {
        var builder = new StringBuilder();
        builder.AppendLine("[ControlView]");
        DumpElement(window, builder, depth: 0, maxDepth, walker: null);
        builder.AppendLine();
        builder.AppendLine("[RawView]");
        var rawWalker = window.Automation.TreeWalkerFactory.GetRawViewWalker();
        DumpElement(window, builder, depth: 0, maxDepth, walker: rawWalker);
        return builder.ToString();
    }

    internal static string DumpAncestors(UIA3Automation automation, AutomationElement element, int maxLevels = 8)
    {
        var builder = new StringBuilder();
        var walker = automation.TreeWalkerFactory.GetControlViewWalker();
        var current = element;
        var level = 0;
        while (current is not null && level < maxLevels)
        {
            builder.AppendLine($"[{level}] {DescribeElement(current)}");
            current = walker.GetParent(current);
            level++;
        }

        return builder.ToString();
    }

    internal static string DumpSubtree(AutomationElement root, int maxDepth = 3)
    {
        var builder = new StringBuilder();
        DumpElement(root, builder, depth: 0, maxDepth, walker: null);
        return builder.ToString();
    }

    internal static string DumpMatchesByRoot(MesAppDriver app, Func<AutomationElement, bool> predicate, int limitPerRoot = 40)
    {
        var builder = new StringBuilder();
        var roots = new List<Window> { app.MainWindow };
        roots.AddRange(app.GetAllTopLevelWindows().Where(window => !ReferenceEquals(window, app.MainWindow)));

        for (var index = 0; index < roots.Count; index++)
        {
            var root = roots[index];
            var matches = root
                .FindAllDescendants()
                .Prepend(root)
                .Where(predicate)
                .Take(limitPerRoot + 1)
                .ToList();

            builder.AppendLine($"[SearchRoot #{index + 1}] Title=\"{GetProperty(() => root.Title)}\" Matches={matches.Count}");
            foreach (var match in matches.Take(limitPerRoot))
            {
                builder.AppendLine($"- {DescribeElement(match)}");
            }

            if (matches.Count > limitPerRoot)
            {
                builder.AppendLine($"- ... 已截断，最多显示 {limitPerRoot} 个结果");
            }

            builder.AppendLine();
        }

        return builder.ToString();
    }

    private static void DumpElement(AutomationElement element, StringBuilder builder, int depth, int maxDepth, ITreeWalker? walker)
    {
        if (depth > maxDepth)
        {
            return;
        }

        var indent = new string(' ', depth * 2);
        builder.Append(indent)
            .Append("- Name=")
            .Append('"').Append(GetProperty(() => element.Name)).Append('"')
            .Append(", Type=")
            .Append(GetProperty(() => element.ControlType.ToString()))
            .Append(", AutomationId=")
            .Append('"').Append(GetProperty(() => element.AutomationId)).Append('"')
            .Append(", Class=")
            .Append('"').Append(GetProperty(() => element.ClassName)).Append('"')
            .AppendLine("\"");

        foreach (var child in GetChildren(element, walker))
        {
            DumpElement(child, builder, depth + 1, maxDepth, walker);
        }
    }

    private static IEnumerable<AutomationElement> GetChildren(AutomationElement element, ITreeWalker? walker)
    {
        if (walker is null)
        {
            return element.FindAllChildren();
        }

        var results = new List<AutomationElement>();
        var child = walker.GetFirstChild(element);
        while (child is not null)
        {
            results.Add(child);
            child = walker.GetNextSibling(child);
        }

        return results;
    }

    private static string Safe(string? value)
    {
        return value ?? string.Empty;
    }

    private static string GetProperty(Func<string?> getter)
    {
        try
        {
            return Safe(getter());
        }
        catch (PropertyNotSupportedException)
        {
            return "<unsupported>";
        }
    }
}

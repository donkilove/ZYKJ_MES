using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace MesDesktop.FlaUI.Tests;

internal static class MesUserModuleSeedHelper
{
    private const string BaseUrl = "http://127.0.0.1:8000";
    private const int DefaultPageSize = 20;
    private const string SeedPassword = "Seed@123456";

    internal static string ResolveBaseUrl() => BaseUrl;

    internal static string CreateDisableTargetUser(TestContext testContext)
    {
        using var client = CreateAuthorizedClient(testContext);
        var roleCode = GetSeedRoleCode(client);
        var username = CreateUniqueUsername("00");
        var payload = JsonSerializer.Serialize(new
        {
            username,
            password = SeedPassword,
            role_code = roleCode,
            is_active = true,
        });
        using var response = client.PostAsync("/api/v1/users", BuildJsonContent(payload)).GetAwaiter().GetResult();
        var body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        Assert.IsTrue(response.IsSuccessStatusCode, $"创建停用目标用户失败。status={(int)response.StatusCode} body={body}");
        testContext.WriteLine($"已创建停用目标用户：{username}，role={roleCode}");
        return username;
    }

    internal static RegistrationRejectSeed CreateRegistrationRejectSeed(TestContext testContext)
    {
        using var client = CreateAuthorizedClient(testContext);
        var pendingTotal = GetPendingRegistrationTotal(client);
        var fillerCount = pendingTotal % DefaultPageSize == 0 ? 0 : DefaultPageSize - (pendingTotal % DefaultPageSize);

        for (var index = 0; index < fillerCount; index++)
        {
            SubmitRegistrationRequest(CreateUniqueUsername("rf"), SeedPassword);
        }

        var targetAccount = CreateUniqueUsername("rr");
        SubmitRegistrationRequest(targetAccount, SeedPassword);
        var totalAfterCreate = pendingTotal + fillerCount + 1;
        var targetPage = ((totalAfterCreate - 1) / DefaultPageSize) + 1;
        testContext.WriteLine($"已创建注册审批目标账号：{targetAccount}，目标页={targetPage}，补齐请求数={fillerCount}");
        return new RegistrationRejectSeed(targetAccount, targetPage);
    }

    internal static OnlineSessionSeed CreateOnlineSessionSeed(TestContext testContext)
    {
        using var client = CreateAuthorizedClient(testContext);
        var roleSeed = CreateCustomRole(client, "ls", "登录会话回归", "登录会话回归测试角色", testContext);
        var username = CreateUniqueUsername("ls");
        CreateUser(client, username, roleSeed.RoleCode, "登录会话回归测试账号");
        var accessToken = Login(username, SeedPassword);
        var sessionTokenId = ExtractSessionTokenId(accessToken);
        testContext.WriteLine($"已创建登录会话目标账号：{username}，session={sessionTokenId}");
        return new OnlineSessionSeed(username, roleSeed.RoleId, roleSeed.RoleCode, roleSeed.RoleName, sessionTokenId);
    }

    internal static RoleSeed CreateRoleManagementDeleteSeed(TestContext testContext)
    {
        using var client = CreateAuthorizedClient(testContext);
        var roleSeed = CreateCustomRole(client, "rd", "角色删除回归", "角色管理删除链路回归", testContext);
        testContext.WriteLine($"已创建角色管理删除目标：{roleSeed.RoleName} ({roleSeed.RoleCode})");
        return roleSeed;
    }

    private static HttpClient CreateAuthorizedClient(TestContext testContext)
    {
        var client = new HttpClient { BaseAddress = new Uri(BaseUrl) };
        var token = LoginAsAdmin(client);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        testContext.WriteLine("已完成测试预置的管理员 API 登录。");
        return client;
    }

    private static string LoginAsAdmin(HttpClient client)
    {
        using var response = client.PostAsync(
            "/api/v1/auth/login",
            new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["username"] = "admin",
                ["password"] = "Admin@123456",
            })).GetAwaiter().GetResult();
        var body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        Assert.IsTrue(response.IsSuccessStatusCode, $"管理员 API 登录失败。status={(int)response.StatusCode} body={body}");

        using var document = JsonDocument.Parse(body);
        return document.RootElement
            .GetProperty("data")
            .GetProperty("access_token")
            .GetString()
            ?? throw new AssertFailedException("管理员 API 登录返回缺少 access_token。");
    }

    private static string Login(string username, string password)
    {
        using var client = new HttpClient { BaseAddress = new Uri(BaseUrl) };
        using var response = client.PostAsync(
            "/api/v1/auth/login",
            new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["username"] = username,
                ["password"] = password,
            })).GetAwaiter().GetResult();
        var body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        Assert.IsTrue(response.IsSuccessStatusCode, $"测试账号 API 登录失败。username={username} status={(int)response.StatusCode} body={body}");

        using var document = JsonDocument.Parse(body);
        return document.RootElement
            .GetProperty("data")
            .GetProperty("access_token")
            .GetString()
            ?? throw new AssertFailedException($"测试账号 {username} 登录返回缺少 access_token。");
    }

    private static string GetSeedRoleCode(HttpClient client)
    {
        using var response = client.GetAsync("/api/v1/roles?page=1&page_size=50").GetAwaiter().GetResult();
        var body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        Assert.IsTrue(response.IsSuccessStatusCode, $"读取角色列表失败。status={(int)response.StatusCode} body={body}");

        using var document = JsonDocument.Parse(body);
        var items = document.RootElement.GetProperty("data").GetProperty("items").EnumerateArray();
        string? fallbackCode = null;
        foreach (var item in items)
        {
            var code = item.GetProperty("code").GetString();
            if (string.IsNullOrWhiteSpace(code))
            {
                continue;
            }

            fallbackCode ??= code;
            if (!string.Equals(code, "system_admin", StringComparison.OrdinalIgnoreCase))
            {
                return code;
            }
        }

        return fallbackCode ?? throw new AssertFailedException("角色列表为空，无法创建用户模块测试数据。");
    }

    private static int GetPendingRegistrationTotal(HttpClient client)
    {
        using var response = client.GetAsync($"/api/v1/auth/register-requests?page=1&page_size=1&status=pending").GetAwaiter().GetResult();
        var body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        Assert.IsTrue(response.IsSuccessStatusCode, $"读取待审批注册申请失败。status={(int)response.StatusCode} body={body}");

        using var document = JsonDocument.Parse(body);
        return document.RootElement.GetProperty("data").GetProperty("total").GetInt32();
    }

    private static void SubmitRegistrationRequest(string account, string password)
    {
        using var client = new HttpClient { BaseAddress = new Uri(BaseUrl) };
        var payload = JsonSerializer.Serialize(new { account, password });
        using var response = client.PostAsync("/api/v1/auth/register", BuildJsonContent(payload)).GetAwaiter().GetResult();
        var body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        Assert.IsTrue(response.IsSuccessStatusCode, $"创建注册申请失败。account={account} status={(int)response.StatusCode} body={body}");
    }

    private static StringContent BuildJsonContent(string payload)
    {
        return new StringContent(payload, Encoding.UTF8, "application/json");
    }

    private static RoleSeed CreateCustomRole(HttpClient client, string prefix, string namePrefix, string description, TestContext testContext)
    {
        var code = CreateUniqueUsername(prefix);
        var name = $"{namePrefix}{code[^4..]}";
        var payload = JsonSerializer.Serialize(new
        {
            code,
            name,
            description,
            role_type = "custom",
            is_enabled = true,
        });
        using var response = client.PostAsync("/api/v1/roles", BuildJsonContent(payload)).GetAwaiter().GetResult();
        var body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        Assert.IsTrue(response.IsSuccessStatusCode, $"创建角色测试数据失败。status={(int)response.StatusCode} body={body}");

        using var document = JsonDocument.Parse(body);
        var data = document.RootElement.GetProperty("data");
        var roleId = data.GetProperty("id").GetInt32();
        var roleCode = data.GetProperty("code").GetString() ?? code;
        var roleName = data.GetProperty("name").GetString() ?? name;
        testContext.WriteLine($"已创建角色测试数据：{roleName} ({roleCode})");
        return new RoleSeed(roleId, roleCode, roleName);
    }

    private static void CreateUser(HttpClient client, string username, string roleCode, string remark)
    {
        var payload = JsonSerializer.Serialize(new
        {
            username,
            password = SeedPassword,
            role_code = roleCode,
            remark,
            is_active = true,
        });
        using var response = client.PostAsync("/api/v1/users", BuildJsonContent(payload)).GetAwaiter().GetResult();
        var body = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        Assert.IsTrue(response.IsSuccessStatusCode, $"创建测试账号失败。username={username} status={(int)response.StatusCode} body={body}");
    }

    private static string ExtractSessionTokenId(string accessToken)
    {
        var segments = accessToken.Split('.');
        Assert.IsTrue(segments.Length >= 2, "access_token 结构非法，无法提取 sid。");
        var payload = segments[1].Replace('-', '+').Replace('_', '/');
        payload = payload.PadRight(payload.Length + (4 - payload.Length % 4) % 4, '=');
        var json = Encoding.UTF8.GetString(Convert.FromBase64String(payload));
        using var document = JsonDocument.Parse(json);
        var sid = document.RootElement.TryGetProperty("sid", out var property)
            ? property.GetString()
            : null;
        return !string.IsNullOrWhiteSpace(sid)
            ? sid
            : throw new AssertFailedException("access_token 中缺少 sid，无法构造登录会话测试数据。");
    }

    private static string CreateUniqueUsername(string prefix)
    {
        var suffix = DateTime.UtcNow.Ticks.ToString()[^8..];
        var normalizedPrefix = prefix.Length > 2 ? prefix[..2] : prefix;
        return $"{normalizedPrefix}{suffix}";
    }
}

internal sealed record RegistrationRejectSeed(string Account, int TargetPage);
internal sealed record OnlineSessionSeed(string Username, int RoleId, string RoleCode, string RoleName, string SessionTokenId);
internal sealed record RoleSeed(int RoleId, string RoleCode, string RoleName);

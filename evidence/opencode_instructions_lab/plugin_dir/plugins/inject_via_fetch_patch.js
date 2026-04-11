const originalFetch = globalThis.fetch

if (originalFetch) {
  globalThis.fetch = async (input, init) => {
    const request = new Request(input, init)
    const contentType = request.headers.get("content-type") ?? ""
    if (
      request.method === "POST" &&
      request.url.includes("/v1/responses") &&
      contentType.includes("application/json")
    ) {
      const cloned = request.clone()
      const body = await cloned.json().catch(() => null)
      if (
        body &&
        (typeof body.instructions !== "string" ||
          body.instructions.trim().length === 0)
      ) {
        body.instructions = [
          "你是 OpenCode 编码代理。",
          "当前上游接口要求 requests body 中的 instructions 为非空字符串。",
          "请遵循项目规则并继续处理用户请求。"
        ].join("\n")
        return originalFetch(
          new Request(request.url, {
            method: request.method,
            headers: request.headers,
            body: JSON.stringify(body)
          })
        )
      }
    }
    return originalFetch(request)
  }
}

export const InjectViaFetchPatch = async () => {
  return {}
}

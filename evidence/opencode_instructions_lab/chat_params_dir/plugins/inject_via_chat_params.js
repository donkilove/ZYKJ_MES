export const InjectViaChatParams = async () => {
  return {
    "chat.params": async (_input, output) => {
      const options = { ...(output.options ?? {}) }
      if (
        typeof options.instructions !== "string" ||
        options.instructions.trim().length === 0
      ) {
        options.instructions = [
          "你是 OpenCode 编码代理。",
          "当前上游接口要求 requests body 中的 instructions 为非空字符串。",
          "请遵循项目规则并继续处理用户请求。"
        ].join("\n")
      }
      output.options = options
    }
  }
}

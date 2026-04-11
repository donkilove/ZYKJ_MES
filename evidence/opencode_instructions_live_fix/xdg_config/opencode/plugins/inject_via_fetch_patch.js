import { writeFile } from "node:fs/promises"

const PATCH_FLAG = Symbol.for("donki.opencode.instructions.fetch_patch.installed")
const TRACE_ENV_NAME = "OPENCODE_INSTRUCTIONS_TRACE_FILE"
const REQUIRED_INSTRUCTIONS = [
  "You are OpenCode.",
  "The upstream endpoint requires a non-empty instructions string.",
  "Follow the project rules and continue handling the request."
].join("\n")

async function writeTrace(payload) {
  const traceFile = process.env[TRACE_ENV_NAME]
  if (!traceFile) {
    return
  }

  try {
    await writeFile(traceFile, JSON.stringify(payload, null, 2), "utf8")
  } catch {}
}

function patchFetch() {
  if (globalThis[PATCH_FLAG]) {
    return
  }

  const originalFetch = globalThis.fetch?.bind(globalThis)
  if (!originalFetch) {
    return
  }

  globalThis[PATCH_FLAG] = true

  globalThis.fetch = async (input, init) => {
    const request = new Request(input, init)
    const contentType = request.headers.get("content-type") ?? ""
    const shouldInspect =
      request.method === "POST" &&
      request.url.includes("/v1/responses") &&
      contentType.includes("application/json")

    if (!shouldInspect) {
      return originalFetch(request)
    }

    const body = await request.clone().json().catch(() => null)
    if (!body) {
      return originalFetch(request)
    }

    let changed = false
    const removedFields = []
    let rewrittenModel = null

    if (
      typeof body.instructions !== "string" ||
      body.instructions.trim().length === 0
    ) {
      body.instructions = REQUIRED_INSTRUCTIONS
      changed = true
    }

    if ("max_output_tokens" in body) {
      delete body.max_output_tokens
      removedFields.push("max_output_tokens")
      changed = true
    }

    if (body.model === "gpt-5-nano") {
      body.model = "gpt-5.4"
      rewrittenModel = "gpt-5.4"
      changed = true
    }

    if (!changed) {
      return originalFetch(request)
    }

    await writeTrace({
      url: request.url,
      injectedAt: new Date().toISOString(),
      instructions: body.instructions,
      removedFields,
      rewrittenModel
    })

    const patchedRequest = new Request(request, {
      body: JSON.stringify(body)
    })

    return originalFetch(patchedRequest)
  }
}

patchFetch()

export async function server() {
  return {}
}

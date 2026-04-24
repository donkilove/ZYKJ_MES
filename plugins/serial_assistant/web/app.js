const portSelect = document.getElementById("port");
const baudrateInput = document.getElementById("baudrate");
const sendText = document.getElementById("sendText");
const receiveLog = document.getElementById("receiveLog");
const statusText = document.getElementById("status");
const clearSendButton = document.getElementById("clearSend");
const clearLogButton = document.getElementById("clearLog");

let activeHandle = null;

function appendLog(message) {
  const now = new Date().toLocaleTimeString();
  receiveLog.textContent += `[${now}] ${message}\n`;
  receiveLog.scrollTop = receiveLog.scrollHeight;
}

function setStatus(message) {
  statusText.textContent = `状态：${message}`;
}

async function request(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload.message || "请求失败");
  }
  return payload;
}

async function loadPorts() {
  const currentValue = portSelect.value;
  const payload = await request("/api/ports");
  portSelect.innerHTML = "";
  for (const item of payload.items) {
    const option = document.createElement("option");
    option.value = item.port;
    option.textContent = `${item.port} - ${item.description}`;
    if (item.port === currentValue) {
      option.selected = true;
    }
    portSelect.appendChild(option);
  }
  if (!portSelect.value && portSelect.options.length > 0) {
    portSelect.selectedIndex = 0;
  }
  appendLog(`已刷新端口列表，共 ${payload.items.length} 项`);
}

async function openPort() {
  setStatus("正在连接");
  const payload = await request("/api/open", {
    method: "POST",
    body: JSON.stringify({
      port: portSelect.value,
      baudrate: Number(baudrateInput.value || 115200),
    }),
  });
  activeHandle = payload.handle;
  setStatus(`已连接 ${payload.port} @ ${payload.baudrate}`);
  appendLog(`已打开端口 ${payload.port} @ ${payload.baudrate}`);
}

async function closePort() {
  if (!activeHandle) {
    setStatus("未连接");
    return;
  }
  await request("/api/close", {
    method: "POST",
    body: JSON.stringify({ handle: activeHandle }),
  });
  appendLog("端口已关闭");
  activeHandle = null;
  setStatus("未连接");
}

async function sendPayload() {
  if (!activeHandle) {
    appendLog("请先打开端口");
    return;
  }
  await request("/api/send", {
    method: "POST",
    body: JSON.stringify({
      handle: activeHandle,
      payload: sendText.value,
    }),
  });
  appendLog(`已发送：${sendText.value}`);
}

async function readOnce() {
  if (!activeHandle) {
    appendLog("请先打开端口");
    return;
  }
  const payload = await request(`/api/read?handle=${encodeURIComponent(activeHandle)}`);
  appendLog(`收到：${payload.payload || "(空)"}`);
}

document.getElementById("refreshPorts").addEventListener("click", () => {
  loadPorts().catch((error) => appendLog(`刷新端口失败：${error.message}`));
});
document.getElementById("open").addEventListener("click", () => {
  openPort().catch((error) => appendLog(`打开端口失败：${error.message}`));
});
document.getElementById("close").addEventListener("click", () => {
  closePort().catch((error) => appendLog(`关闭端口失败：${error.message}`));
});
document.getElementById("send").addEventListener("click", () => {
  sendPayload().catch((error) => appendLog(`发送失败：${error.message}`));
});
document.getElementById("read").addEventListener("click", () => {
  readOnce().catch((error) => appendLog(`读取失败：${error.message}`));
});
clearSendButton.addEventListener("click", () => {
  sendText.value = "";
});
clearLogButton.addEventListener("click", () => {
  receiveLog.textContent = "";
});

loadPorts().catch((error) => appendLog(`初始化失败：${error.message}`));

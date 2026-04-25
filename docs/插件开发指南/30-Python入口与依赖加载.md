# Python入口与依赖加载

## 1. 目的

- 本文档说明插件如何以 Python 入口脚本接入宿主。
- 本文档说明宿主提供的环境变量、`sys.path` 组装方式和 `ready` 消息要求。

## 2. 适用范围

适用对象：

1. 编写 `launcher.py` 的插件开发者
2. 维护宿主启动链与进程协议的人
3. 需要排查插件启动后为什么无法导入依赖、无法返回页面入口的人

## 3. 与其他分册关系

- 本文档建立在 `20-插件包结构与清单规范.md` 之上。
- 本文档只解释 Python 启动链，不解释前端页面组织。
- `40-UI承载与前后端接口.md` 继续解释 `entry_url` 与 `heartbeat_url`。

## 4. `launcher.py` 的职责

当前插件体系下，`launcher.py` 负责：

1. 读取宿主注入的环境变量
2. 计算插件目录、依赖目录和业务代码目录
3. 把这些目录插入 `sys.path`
4. 启动插件自己的本地服务
5. 向宿主输出结构化 `ready` 消息
6. 保持主进程存活，直到宿主关闭

`launcher.py` 不负责：

1. 决定 Python 解释器路径
2. 安装第三方依赖到宿主环境
3. 修改宿主的 UI 组件

## 5. 宿主会注入的关键环境变量

当前宿主启动插件前会注入：

1. `PYTHONHOME`
2. `MES_PLUGIN_ID`
3. `MES_PLUGIN_DIR`
4. `MES_PLUGIN_VENDOR_DIR`
5. `MES_PLUGIN_APP_DIR`
6. `MES_RUNTIME_DIR`
7. `MES_HOST_SESSION_ID`

插件开发者最常用的是：

1. `MES_PLUGIN_DIR`
2. `MES_PLUGIN_VENDOR_DIR`
3. `MES_PLUGIN_APP_DIR`

## 6. 当前推荐写法

当前样板插件的关键写法如下：

```python
BASE_DIR = Path(__file__).resolve().parent
plugin_dir = Path(os.environ.get("MES_PLUGIN_DIR", str(BASE_DIR)))
vendor_dir = Path(os.environ.get("MES_PLUGIN_VENDOR_DIR", str(plugin_dir / "vendor")))
app_dir = Path(os.environ.get("MES_PLUGIN_APP_DIR", str(plugin_dir / "app")))

sys.path.insert(0, str(vendor_dir))
sys.path.insert(0, str(plugin_dir))
sys.path.insert(0, str(app_dir))
```

这段代码的含义是：

1. 优先使用宿主提供的目录
2. 如果宿主未提供，则退回插件目录内的默认相对路径
3. 插件私有依赖、插件根目录和业务代码目录都会进入 `sys.path`

## 7. `ready` 消息要求

插件启动完成后，必须通过标准输出输出一条 JSON 消息。

当前样板使用的消息结构如下：

```json
{
  "event": "ready",
  "pid": 12345,
  "entry_url": "http://127.0.0.1:43125/index.html",
  "heartbeat_url": "http://127.0.0.1:43125/__heartbeat__"
}
```

最小要求：

1. 必须是合法 JSON
2. `event` 必须是 `ready`
3. 必须包含 `pid`
4. 必须包含 `entry_url`
5. 应该包含 `heartbeat_url`

## 8. 当前样板完整链路

当前 `serial_assistant` 的启动链路是：

1. 宿主执行 `python.exe launcher.py`
2. `launcher.py` 组装 `sys.path`
3. `launcher.py` 导入 `app.server.start_server`
4. `start_server` 启动本地 HTTP 服务
5. `launcher.py` 打印 `ready` JSON
6. 宿主读取第一行标准输出并解析
7. 宿主拿到 `entry_url` 后内嵌页面

## 9. 允许事项

1. 可以在 `launcher.py` 中做最小初始化逻辑
2. 可以把插件业务代码放在 `app/`
3. 可以把第三方依赖放在 `vendor/`
4. 可以把页面资源放在 `web/`

## 10. 禁止事项

1. 依赖系统 Python 环境变量或用户手工安装的 Python
2. 把第三方库安装进宿主公共目录
3. 用非结构化文本代替 `ready` 消息
4. 把 `entry_url` 写死成固定端口
5. 让插件跳过 `heartbeat_url`

## 11. 常见错误

1. `sys.path` 只插入了 `app/`，漏掉 `vendor/`
2. 输出了日志文本在 `ready` 前面，导致宿主读取第一行失败
3. `entry_url` 指向的页面不存在
4. `heartbeat_url` 路径没有真正监听
5. 插件进程启动后立即退出，宿主页面刚打开就断线

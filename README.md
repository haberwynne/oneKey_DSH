# oneKey_DSH

> 双击一个 BAT，就能在独立窗口里跑起 DeepSeek Harness —— Windows 11 + Microsoft Edge 环境实测可用。

一个对官方一键命令 `npx @deepseek-ai/dsh web` 的 Windows 封装脚本。它把"开终端 → 敲命令 → 复制带 token 的地址 → 粘进浏览器"这一串手动操作，压缩成一次双击。

## 为什么需要它

官方的一键命令是 `npx @deepseek-ai/dsh web`，但它有两个日常使用上的不便：

| 官方命令行为 | oneKey_DSH 的处理 |
|--------------|-------------------|
| 命令会在终端里前台常驻，关窗口即停服务 | 最小化后台运行，日志写入临时文件 |
| 自动打开的是普通浏览器标签页（带地址栏、书签栏、其他标签） | 用 Edge 的 `--app` 应用模式，独立窗口、无地址栏，像个原生应用 |
| 每次端口被占用都要手动找 PID 杀进程 | 启动前自动释放端口 |
| 带 token 的地址需要手动复制 | 从日志轮询提取，自动拼接并打开 |

## 特性

- **一键启动**：双击 `oneKey_DSH.bat` 即可，无需敲任何命令
- **独立窗口**：通过 Edge `--app` 模式打开，界面干净，无浏览器地址栏与标签页
- **自动清理**：启动前自动杀掉占用目标端口的旧进程、清空旧日志
- **智能等待**：轮询服务日志，检测到带 token 的完整地址后立即打开，无需盲等
- **环境自检**：检测 `npx` 是否存在，缺失时给出明确的安装指引
- **Edge 路径自动探测**：依次检查多个常见安装位置与注册表，不做硬编码
- **端口可配**：默认 `3080`，也支持命令行传参
- **免交互安装**：`npx` 带 `--yes`，包未缓存时自动确认安装，不会卡在确认提示上
- **超时保护**：默认等待 60 次（约 2 分钟），超时时直接打印日志尾部内容
- **零依赖**：纯 BAT 实现，不引入任何第三方工具

## 环境要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10 / 11（在 Windows 11 上实测通过） |
| Node.js | 已安装并加入 PATH（需包含 `npx`），建议 **22.19.0 或更高**（部分依赖要求 `>=22.19.0`） |
| 浏览器 | Microsoft Edge（用于应用模式；缺失时回退到默认浏览器） |
| 网络 | 首次运行需联网，`npx` 会拉取 `@deepseek-ai/dsh` 包 |

## 快速开始

1. 确认已安装 Node.js：在终端执行 `node -v` 与 `npx -v`，两条命令都应正常输出版本号（`node` 建议 22.19.0 以上）
2. 下载 `oneKey_DSH.bat` 到任意目录
3. 双击运行

脚本会依次输出四个步骤的进度，等待服务就绪期间会持续打印小圆点表示心跳：

```
[1/4] 正在清理占用端口 3080 的旧进程...
[2/4] 正在启动 DeepSeek Harness 服务 (端口 3080)...
[3/4] 正在等待服务就绪 (首次运行需下载依赖, 可能较慢)
.....
[4/4] 正在以独立窗口打开界面...
```

首次运行需要联网下载 `@deepseek-ai/dsh` 包，可能要等一到两分钟；之后有缓存，通常几秒即可。稍等片刻，一个不带地址栏的 Edge 窗口会弹出并载入 DSH 的 Web UI。

### 指定端口

在命令行中传入端口号作为第一个参数：

```bat
oneKey_DSH.bat 8080
```

## 工作原理

整个脚本分五步执行：

| 步骤 | 动作 | 说明 |
|------|------|------|
| 0 | 环境自检 | `where npx` 检测 Node.js 环境，缺失则提示并退出 |
| 1 | 探测 Edge | 遍历 `%ProgramFiles(x86)%`、`%ProgramFiles%`、`%LocalAppData%` 三个路径，再查注册表 `App Paths\msedge.exe` |
| 2 | 清理现场 | `netstat -ano` 找出占用目标端口的 PID 并 `taskkill`，删除旧日志 |
| 3 | 后台启动 | `start /min cmd /c` 以最小化窗口启动 `npx --yes @deepseek-ai/dsh web --port <PORT> --no-open`，stdout/stderr 重定向到 `%TEMP%\dsh_start.log` |
| 4 | 轮询等待 | 每约 2 秒用 `findstr` 在日志里搜 `dsh web: http://`，取第 3 个 token 即完整地址；最多等 60 轮 |
| 5 | 打开窗口 | `start "" msedge.exe --app="<完整地址>"` |

这里有三个容易踩坑的关键点：

- `--no-open`：让 DSH 不要自己打开浏览器，改由脚本在拿到带 token 的地址后，用应用模式打开。
- `--yes`：`npx` 在包未缓存时会交互式询问 `Ok to proceed? (y)`。本脚本把输出重定向到日志，提示既看不见也无法回答，进程会**永久挂起**直到超时 —— 必须用 `--yes` 免去交互。
- 延时用 `ping -n` 而非 `timeout`：`timeout` 在 stdin 被重定向的场景下会直接报 `Input redirection is not supported` 并退出，`ping` 无此限制。

## 配置项

打开 `oneKey_DSH.bat`，修改顶部「配置项」区块：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `PORT` | DSH 服务监听端口 | `3080` |
| `LOG_FILE` | 服务日志文件路径 | `%TEMP%\dsh_start.log` |
| `MAX_WAIT` | 等待服务就绪的最大轮数（每轮约 2 秒） | `60` |

如 Edge 不在常见位置，脚本会尝试读注册表；仍找不到时会回退用系统默认浏览器打开。

## 常见问题

### 提示"未检测到 Node.js 环境"？

安装 Node.js（<https://nodejs.org/>）后**重新打开**终端窗口，再运行脚本。已安装但仍报错，通常是 PATH 未刷新，重启资源管理器或重新登录即可。

### 服务启动超时？

脚本会把日志尾部内容**直接回显到窗口**，并打印完整日志路径，便于当场判断。常见表现对照：

| 日志表现 | 含义 | 处理 |
|----------|------|------|
| `Ok to proceed? (y)` | npx 在等交互确认安装，而提示不可见 | 使用带 `--yes` 的当前版本脚本；若仍出现，说明用的是旧版 |
| 只有下载进度、无报错 | 首次拉包太慢 | 调大 `MAX_WAIT`，或先在终端跑一次 `npx --yes @deepseek-ai/dsh web` 预热缓存 |
| `ETIMEDOUT` / `ECONNREFUSED` | 网络不通 | 检查网络或 npm registry 配置 |
| `EBADENGINE` 之后无输出 | Node 版本低于依赖要求 | 升级 Node.js 到 22.19.0 或更高 |

### 打开了浏览器标签页而不是独立窗口？

说明 Edge 路径探测失败，脚本回退到了默认浏览器。请手动确认 `msedge.exe` 的位置并在脚本中写死 `EDGE_PATH`。

### 界面提示 token 无效 / 打开空白页？

DSH 的访问地址是带 token 的，且服务重启后 token 会变。请始终通过本脚本打开，不要复用上一次的地址。

### 退出脚本后服务还在跑吗？

在。服务是独立的最小化窗口进程，脚本退出不影响它。需要停止时，关掉那个最小化的控制台窗口，或重新运行脚本（会自动杀掉占用该端口的进程）。

### 日志文件在哪？

`%TEMP%\dsh_start.log`（在资源管理器地址栏输入 `%TEMP%` 回车即可）。想查看服务输出时很有用。

## 项目结构

```
oneKey_DSH/
├── oneKey_DSH.bat      # 主脚本
├── README.md           # 本文件
├── LICENSE             # MIT
├── .gitignore
└── docs/
    └── usage.md        # 使用与排错详解
```

## 关于 DeepSeek Harness

DeepSeek Harness（DSH）是 DeepSeek 推出的开源 agent harness，目前处于开发者预览阶段。它构建在 Cordis 插件内核之上，模型、工具、技能、会话、沙箱、存储、循环调度乃至 UI 等能力都以插件形式提供，可以按配置替换或重组；每次运行都会写入只追加的会话日志，可在 Trajectory 视图中按来源检视。它提供 Standard、Code、Minimal、Creator 等多种运行时模式。

- 官网：<https://www.deepseek.com/harness/>
- 源码：<https://github.com/deepseek-ai/deepseek-harness>
- 文档：<https://deepseek-harness.github.io/deepseek-harness/en/guide/quickstart>
- 社区插件：<https://github.com/topics/dsh-plugin>

## About

A tiny Windows batch wrapper around the official one-liner `npx @deepseek-ai/dsh web`. It kills stale processes on the target port, launches the DSH service minimized in the background, polls the log for the tokenized URL, then opens it in a clean Edge `--app` window. Tested on Windows 11 with Microsoft Edge.

## 免责声明

本项目为个人使用便利而封装的启动脚本，与 DeepSeek 官方无隶属关系。脚本仅做进程管理与浏览器唤起，不修改、不重打包 DSH 本体。使用前请确认符合 DeepSeek Harness 的许可与使用条款。

## License

MIT

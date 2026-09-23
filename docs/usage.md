# 使用与排错详解

## 目录

- [安装与首次运行](#安装与首次运行)
- [脚本执行流程逐步解析](#脚本执行流程逐步解析)
- [自定义配置](#自定义配置)
- [常见问题排查](#常见问题排查)
- [进阶用法](#进阶用法)

---

## 安装与首次运行

### 1. 前置检查

打开终端（Win + R 输入 `cmd`），依次执行：

```bat
node -v
npx -v
```

两者都能输出版本号即表示环境就绪。若提示"不是内部或外部命令"，说明未安装 Node.js 或未加入 PATH。

### 2. 首次运行建议

第一次运行时，`npx` 需要从 npm registry 下载 `@deepseek-ai/dsh` 包（体积不小），耗时会明显长于后续运行。

建议**先在终端手动跑一次**，把包缓存下来：

```bat
npx @deepseek-ai/dsh web
```

看到输出里出现形如下面这一行，说明服务正常：

```
dsh web: http://127.0.0.1:3080/?token=xxxxxxxx
```

按 `Ctrl + C` 停掉，之后再用脚本启动就会快很多。

### 3. 双击运行

双击 `oneKey_DSH.bat`。如果杀毒软件或 SmartScreen 弹出拦截提示，选择"仍要运行"（脚本只做进程管理和浏览器唤起，可自行审阅源码）。

---

## 脚本执行流程逐步解析

```
开始
 │
 ├─ [0] where npx  ──────────► 缺失? ──► 提示安装 Node.js 并退出
 │
 ├─ [1] 探测 Edge ───────────► 依次检查:
 │                              %ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe
 │                              %ProgramFiles%\Microsoft\Edge\Application\msedge.exe
 │                              %LocalAppData%\Microsoft\Edge\Application\msedge.exe
 │                              HKLM\...\App Paths\msedge.exe（注册表兜底）
 │
 ├─ [2] 清理现场 ────────────► netstat -ano | findstr ":3080 "  →  taskkill /f /pid
 │                              del %TEMP%\dsh_start.log
 │
 ├─ [3] 后台启动 ────────────► start "" /min cmd /c
 │                              "npx @deepseek-ai/dsh web --port 3080 --no-open > 日志 2>&1"
 │
 ├─ [4] 轮询等待 ────────────► 每 2 秒 findstr "dsh web: http://" 日志
 │                              命中 → 取第 3 个 token 作为 FULL_URL
 │                              30 轮未命中 → 报错并打印日志路径
 │
 └─ [5] 打开窗口 ────────────► start "" msedge.exe --app="FULL_URL"
```

### 为什么用 `--no-open`

DSH 默认会自己唤起浏览器，但那时打开的地址未必包含完整 token，或会在普通标签页中打开。加上 `--no-open` 后，由脚本负责在拿到带 token 的地址后再打开，从而保证：

1. 地址一定完整（含 token）
2. 一定以 Edge 应用模式打开

### 为什么要把日志重定向到文件

`npx` 的输出中**只有一行**包含带 token 的完整地址，脚本需要反复读取它来轮询。重定向到文件后，`findstr` 就可以稳定地抓取，不受控制台缓冲影响。

---

## 自定义配置

编辑 `oneKey_DSH.bat` 顶部的「配置项」区块：

```bat
set "PORT=3080"
if not "%~1"=="" set "PORT=%~1"
set "LOG_FILE=%TEMP%\dsh_start.log"
set "MAX_WAIT=30"
```

| 变量 | 作用 | 调整建议 |
|------|------|----------|
| `PORT` | 服务监听端口 | 被占用时换一个，如 `8080` |
| `LOG_FILE` | 日志输出路径 | 想长期留档可改到非临时目录 |
| `MAX_WAIT` | 最大等待轮数（每轮 2 秒） | 首次运行慢，可调到 `60`（2 分钟） |

### 固定 Edge 路径

如果自动探测失败（脚本提示"未找到 Microsoft Edge"），在「配置项」区块手动加一行：

```bat
set "EDGE_PATH=C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
```

查看 Edge 实际位置的方法：打开 Edge，地址栏输入 `edge://version`，看「可执行文件路径」一行。

---

## 常见问题排查

### Q1：双击后窗口一闪而过

说明脚本在早期步骤就退出了。原因通常有两种：

- 未安装 Node.js，走到了环境自检的退出分支
- 脚本文件编码被改坏

解决：在终端里手动执行脚本以看到完整报错：

```bat
cd /d "脚本所在目录"
oneKey_DSH.bat
```

### Q2：提示"服务启动超时"

脚本已打印日志路径，直接打开看最后几行：

```bat
type "%TEMP%\dsh_start.log"
```

| 日志表现 | 含义 | 处理 |
|----------|------|------|
| 只有下载进度条 | 首次拉包太慢 | 调大 `MAX_WAIT`，或先手动 `npx` 缓存一次 |
| `ETIMEDOUT` / `ECONNREFUSED` | 网络不通 | 检查网络或 npm registry 配置 |
| 停在 `Need to install the following packages` | npx 在等交互确认 | 终端里手动跑一次完成确认 |
| 端口占用报错 | `[2]` 步没杀干净 | 换个 `PORT`，或手动 `netstat -ano \| findstr ":3080 "` 找 PID 杀 |

### Q3：打开的窗口有地址栏

说明走的是默认浏览器回退分支，即 Edge 没被探测到。按上文「固定 Edge 路径」处理。

### Q4：界面提示 token 失效

DSH 的地址带一次性 token，服务重启后旧地址即失效。**每次都通过脚本打开**，不要收藏或复用上一次的地址。

### Q5：服务停不掉

服务跑在独立的最小化控制台窗口里，脚本退出后它仍在运行。停止方式：

- 找到那个最小化的控制台窗口关掉它
- 或直接重新运行脚本（`[2]` 步会自动杀掉占用该端口的进程）

### Q6：想让它开机自动启动

把 `oneKey_DSH.bat` 的快捷方式放到启动目录：

1. Win + R 输入 `shell:startup` 回车
2. 把脚本的快捷方式拖进去

### Q7：想在桌面放个图标

右键 `oneKey_DSH.bat` → 发送到 → 桌面快捷方式，再右键快捷方式 → 属性 → 更改图标，挑一个 `.ico` 即可。

---

## 进阶用法

### 多个 DSH 实例并行

不同端口可以同时跑：

```bat
oneKey_DSH.bat 3080
oneKey_DSH.bat 3081
```

每个实例会有各自的独立窗口与日志（日志文件同名，后启动的会覆盖前者，如需区分请修改 `LOG_FILE`）。

### 换用其他浏览器

Edge 之外的 Chromium 系浏览器同样支持 `--app`，把 `EDGE_PATH` 指向对应可执行文件即可，例如 Chrome：

```bat
set "EDGE_PATH=C:\Program Files\Google\Chrome\Application\chrome.exe"
```

### 保留日志用于排查

把 `LOG_FILE` 改到固定目录，并去掉脚本中的 `del /f /q "%LOG_FILE%"` 一行：

```bat
set "LOG_FILE=%~dp0logs\dsh_start.log"
```

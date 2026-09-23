# 更新日志

本项目所有值得记录的变更都会写入本文件。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本 2.0.0](https://semver.org/lang/zh-CN/)。

## [Unreleased]

暂无。

## [1.0.0] - 2026-09-23

首个基线版本。在 Windows 11 + Microsoft Edge 环境实测可用。

### 新增

- 一键启动 DeepSeek Harness Web UI，并自动以 Edge 应用模式（独立窗口、无地址栏）打开
- 自动探测 Microsoft Edge 路径：依次检查 `%ProgramFiles(x86)%`、`%ProgramFiles%`、`%LocalAppData%`，再查注册表 `App Paths\msedge.exe` 兜底；全部失败时回退系统默认浏览器
- 启动前自动释放被占用的目标端口、清空旧日志
- 轮询服务日志提取带 token 的完整访问地址，无需手动复制粘贴
- 环境自检：检测 `npx` 是否存在，缺失时给出安装指引而非静默失败
- 支持命令行传入端口：`oneKey_DSH.bat 8080`
- 支持版本查询：`oneKey_DSH.bat -v`
- 等待服务就绪期间打印心跳圆点，区分「正在等待」与「已卡死」
- 超时保护：默认 60 轮（约 2 分钟），超时时自动回显日志尾部内容便于定位

### 修复

- `npx` 在包未缓存时会交互式询问 `Ok to proceed? (y)`，而脚本将输出重定向到日志文件，导致提示既不可见也无法应答、进程永久挂起直至超时。改为 `npx --yes` 自动确认
- 延时使用 `timeout` 在 stdin 被重定向的场景下会报 `Input redirection is not supported, exiting the process immediately` 并退出，导致轮询空转、瞬间跑满计数后误报超时。改用 `ping -n <秒数+1> 127.0.0.1 >nul`
- 自动探测 Edge 路径时，`%ProgramFiles(x86)%` 中的括号会破坏 `for ... in ( ... )` 集合的解析（报 `was unexpected at this time`）。改用 `set` 变量 + `if exist` 判断
- 凡涉及 `EDGE_PATH`（其值含 `(x86)`）的分支若写成 `( ... )` 代码块，值中的 `)` 会被当作块结束符导致语法错误。改用 `goto` 分支

### 说明

- 官方一键命令为 `npx @deepseek-ai/dsh web`，本项目是其 Windows 封装（官网 <https://www.deepseek.com/harness/>）
- 建议 Node.js 22.19.0 或更高（部分依赖声明 `engines.node >= 22.19.0`）
- 首次运行需联网下载 `@deepseek-ai/dsh` 包，可能耗时一到两分钟

[Unreleased]: https://github.com/haberwynne/oneKey_DSH/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/haberwynne/oneKey_DSH/releases/tag/v1.0.0

@echo off
chcp 65001 >nul
setlocal
title DeepSeek Harness 一键启动 (oneKey_DSH)

:: =====================================================================
::  oneKey_DSH - DeepSeek Harness 一键启动脚本 (Windows 11 + Edge)
::
::  用途: 双击即可在后台启动 DSH 本地服务, 并自动用 Edge 应用模式
::        (独立窗口 / 无地址栏) 打开 Web UI。
::
::  用法: oneKey_DSH.bat            使用默认端口 3080
::        oneKey_DSH.bat 8080       指定端口
::
::  依赖: Node.js (含 npx)、Microsoft Edge
:: =====================================================================

:: ========== 配置项 ==========
set "PORT=3080"
if not "%~1"=="" set "PORT=%~1"
set "LOG_FILE=%TEMP%\dsh_start.log"
set "MAX_WAIT=30"

:: ========== 0. 环境自检: Node.js / npx ==========
where npx >nul 2>&1
if errorlevel 1 (
    echo.
    echo [错误] 未检测到 Node.js 环境 ^(缺少 npx^)
    echo        请先安装 Node.js: https://nodejs.org/
    echo.
    pause
    exit /b 1
)

:: ========== 1. 自动探测 Microsoft Edge 路径 ==========
::  注意: 不能把 %ProgramFiles(x86)% 放进 for 的集合里, 其中的括号会破坏解析
set "EDGE_X86=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
set "EDGE_X64=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
set "EDGE_USR=%LocalAppData%\Microsoft\Edge\Application\msedge.exe"

set "EDGE_PATH="
if exist "%EDGE_X86%" set "EDGE_PATH=%EDGE_X86%"
if not defined EDGE_PATH if exist "%EDGE_X64%" set "EDGE_PATH=%EDGE_X64%"
if not defined EDGE_PATH if exist "%EDGE_USR%" set "EDGE_PATH=%EDGE_USR%"

:: 仍找不到时查注册表兜底
if not defined EDGE_PATH (
    for /f "skip=2 tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe" /ve 2^>nul') do (
        if exist "%%~b" set "EDGE_PATH=%%~b"
    )
)

:: ========== 2. 清理旧进程与旧日志 ==========
echo [1/4] 正在清理占用端口 %PORT% 的旧进程...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%PORT% "') do (
    taskkill /f /pid %%a >nul 2>&1
)
del /f /q "%LOG_FILE%" >nul 2>&1
timeout /t 1 /nobreak >nul

:: ========== 3. 后台启动 DSH 服务, 输出重定向到日志 ==========
echo [2/4] 正在启动 DeepSeek Harness 服务 ^(端口 %PORT%^)...
start "" /min cmd /c "npx @deepseek-ai/dsh web --port %PORT% --no-open > "%LOG_FILE%" 2>&1"

:: ========== 4. 轮询日志, 等待带 token 的完整访问地址 ==========
echo [3/4] 正在等待服务就绪...
set "count=0"

:wait
timeout /t 2 /nobreak >nul

:: DSH 启动完成后会输出形如 "dsh web: http://127.0.0.1:3080/?token=xxx"
for /f "tokens=3" %%u in ('findstr /c:"dsh web: http://" "%LOG_FILE%" 2^>nul') do (
    set "FULL_URL=%%u"
    goto open_browser
)

set /a count+=1
if %count% geq %MAX_WAIT% (
    echo.
    echo [错误] 服务启动超时 ^(已等待 %MAX_WAIT% 次, 每次 2 秒^)
    echo        请检查日志: %LOG_FILE%
    echo.
    pause
    exit /b 1
)
goto wait

:: ========== 5. 用 Edge 应用模式打开 Web UI ==========
::  注意: 这里刻意不用 ( ... ) 代码块。EDGE_PATH 取值形如
::        C:\Program Files (x86)\...\msedge.exe, 展开进代码块时其中的
::        ")" 会提前闭合块, 导致 "was unexpected at this time" 报错。
:open_browser
if defined EDGE_PATH goto edge_open

echo [警告] 未找到 Microsoft Edge, 改用系统默认浏览器打开
start "" "%FULL_URL%"
exit /b 0

:edge_open
echo [4/4] 正在以独立窗口打开界面...
start "" "%EDGE_PATH%" --app="%FULL_URL%"

exit /b 0

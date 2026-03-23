@echo off
setlocal EnableDelayedExpansion

set "SERVICE_NAME=WeChatClaudeCode"
set "PROJECT_DIR=%~dp0.."
set "DATA_DIR=%USERPROFILE%\.wechat-claude-code"
set "NODE_BIN=node"

if "%1"=="" goto usage
if "%1"=="start" goto start
if "%1"=="stop" goto stop
if "%1"=="restart" goto restart
if "%1"=="status" goto status
if "%1"=="logs" goto logs
goto usage

:start
sc query %SERVICE_NAME% >nul 2>nul
if %ERRORLEVEL%==0 (
    echo Service already installed
    sc query %SERVICE_NAME%
    goto end
)

echo Starting %SERVICE_NAME%...

rem 创建日志目录
if not exist "%DATA_DIR%\logs" mkdir "%DATA_DIR%\logs"

rem 使用 node 直接启动（Windows 服务需要额外工具，这里用简单方式）
rem 推荐使用 PM2: npm install -g pm2 && pm2 start "%PROJECT_DIR%\dist\main.js" --name %SERVICE_NAME%

rem 查找 node
where node >nul 2>nul
if %ERRORLEVEL%==0 (
    set "NODE_BIN=node"
) else (
    set "NODE_BIN=%ProgramFiles%\nodejs\node.exe"
)

rem 创建启动脚本
echo @echo off > "%TEMP%\%SERVICE_NAME%_start.bat"
echo cd /d "%PROJECT_DIR%" >> "%TEMP%\%SERVICE_NAME%_start.bat"
echo "%NODE_BIN%" dist\main.js start >> "%TEMP%\%SERVICE_NAME%_start.bat"

rem 使用 Windows 自带任务计划程序实现开机自启
schtasks /create /tn "%SERVICE_NAME%" /tr "cmd /c \"%TEMP%\%SERVICE_NAME%_start.bat\"" /sc onlogon /ru "%USERNAME%" /f >nul 2>nul
schtasks /run /tn "%SERVICE_NAME%" >nul 2>nul

echo Started %SERVICE_NAME% daemon ^(Windows^)
echo NOTE: Using Task Scheduler for auto-start
echo.
echo For better management, install PM2:
echo   npm install -g pm2
echo   pm2 start "%PROJECT_DIR%\dist\main.js" --name %SERVICE_NAME%
echo   pm2 save
echo   pm2 startup
goto end

:stop
schtasks /end /tn "%SERVICE_NAME%" >nul 2>nul
schtasks /delete /tn "%SERVICE_NAME%" /f >nul 2>nul
echo Stopped %SERVICE_NAME% daemon
goto end

:restart
call :stop
timeout /t 1 /nobreak >nul
call :start
goto end

:status
schtasks /query /tn "%SERVICE_NAME%" >nul 2>nul
if %ERRORLEVEL%==0 (
    echo %SERVICE_NAME% is installed
    schtasks /query /tn "%SERVICE_NAME%" /fo LIST | findstr /i "Status"
) else (
    echo %SERVICE_NAME% is not installed
)

rem 检查进程是否在运行
tasklist /fi "IMAGENAME eq node.exe" /fo LIST 2>nul | findstr "main.js"
goto end

:logs
if exist "%DATA_DIR%\logs" (
    echo === Recent logs ===
    for /f "tokens=*" %%f in ('dir /b /o-d "%DATA_DIR%\logs\*.log" 2^>nul') do (
        echo --- %%f ---
        type "%DATA_DIR%\logs\%%f"
        echo.
    )
) else (
    echo No logs found
)
goto end

:usage
echo Usage: daemon.bat {start^|stop^|restart^|status^|logs}
echo.
echo   start   - Start the service
echo   stop    - Stop the service
echo   restart - Restart the service
echo   status  - Show service status
echo   logs    - Show recent logs
echo.
echo NOTE: On Windows, this uses Task Scheduler for auto-start.
echo       For production use, PM2 is recommended:
echo         npm install -g pm2
echo         pm2 start dist\main.js --name %SERVICE_NAME%
echo.
:end

#!/bin/bash
set -euo pipefail

DATA_DIR="${HOME}/.wechat-claude-code"
PLIST_LABEL="com.wechat-claude-code.bridge"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 跨平台支持：检测操作系统
detect_os() {
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*) echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

OS_TYPE=$(detect_os)

# 根据系统选择 plist 路径 (macOS) 或 service 路径 (Linux)
if [ "$OS_TYPE" = "macos" ]; then
  PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"
elif [ "$OS_TYPE" = "linux" ]; then
  # Linux: 使用用户级 systemd，不需 root 权限
  SYSTEMD_UNIT="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/${PLIST_LABEL}.service"
fi

is_loaded() {
  if [ "$OS_TYPE" = "macos" ]; then
    launchctl print gui/$(id -u)/"${PLIST_LABEL}" &>/dev/null
  elif [ "$OS_TYPE" = "linux" ]; then
    systemctl --user is-active --quiet "${PLIST_LABEL}" 2>/dev/null
  elif [ "$OS_TYPE" = "windows" ]; then
    schtasks /query /tn "${PLIST_LABEL}" &>/dev/null
  fi
}

need_root() {
  # 检查是否需要 root 权限
  if [ "$OS_TYPE" = "linux" ]; then
    # systemd --user 不需要 root
    return 1
  elif [ "$OS_TYPE" = "macos" ]; then
    # launchd 对特定目录需要 root
    [ ! -w "$PLIST_PATH" ] && [ ! -w "$(dirname "$PLIST_PATH")" ]
    return $?
  fi
  return 1
}

start_service() {
  mkdir -p "$DATA_DIR/logs"

  # Find node binary, resolving nvm/fnm/volta paths
  NODE_BIN="$(command -v node || echo '/usr/local/bin/node')"

  if [ "$OS_TYPE" = "macos" ]; then
    cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${PLIST_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${NODE_BIN}</string>
    <string>${PROJECT_DIR}/dist/main.js</string>
    <string>start</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${PROJECT_DIR}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${DATA_DIR}/logs/stdout.log</string>
  <key>StandardErrorPath</key>
  <string>${DATA_DIR}/logs/stderr.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>${NODE_BIN%/*}:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
PLIST
    launchctl load "$PLIST_PATH"
    echo "Started wechat-claude-code daemon (macOS)"
  elif [ "$OS_TYPE" = "linux" ]; then
    # Linux: 使用用户级 systemd (不需要 root)
    mkdir -p "$(dirname "$SYSTEMD_UNIT")"

    cat > "$SYSTEMD_UNIT" <<SERVICE
[Unit]
Description=WeChat Claude Code Bridge
After=default.target

[Service]
Type=simple
ExecStart=${NODE_BIN} ${PROJECT_DIR}/dist/main.js start
WorkingDirectory=${PROJECT_DIR}
Restart=always
RestartSec=5
StandardOutput=append:${DATA_DIR}/logs/stdout.log
StandardError=append:${DATA_DIR}/logs/stderr.log
Environment="PATH=${NODE_BIN%/*}:/usr/local/bin:/usr/bin:/bin"

[Install]
WantedBy=default.target
SERVICE

    # 启用 linger 允许用户开机自启（可选，需要 sudo）
    # loginctl enable-linger "$USER" 2>/dev/null || true

    systemctl --user daemon-reload
    systemctl --user enable "${PLIST_LABEL}"
    systemctl --user start "${PLIST_LABEL}"
    echo "Started wechat-claude-code daemon (Linux/systemd --user)"
    echo "Service installed at: $SYSTEMD_UNIT"
  elif [ "$OS_TYPE" = "windows" ]; then
    # Windows: 使用 Task Scheduler (Git Bash/MSYS2 环境)
    # 转换路径为 Windows 格式
    WIN_PROJECT_DIR=$(cygpath -w "$PROJECT_DIR" 2>/dev/null || echo "$PROJECT_DIR")
    WIN_NODE_BIN=$(which node 2>/dev/null || echo "node")
    WIN_NODE_BIN=$(cygpath -w "$WIN_NODE_BIN" 2>/dev/null || echo "$WIN_NODE_BIN")

    # 创建启动批处理脚本
    cat > "/tmp/${PLIST_LABEL}_start.bat" <<BAT
@echo off
cd /d "${WIN_PROJECT_DIR}"
"${WIN_NODE_BIN}" dist\\main.js start
BAT

    # 创建任务计划
    schtasks /create /tn "${PLIST_LABEL}" /tr "cmd /c C:\\temp\\${PLIST_LABEL}_start.bat" /sc onlogon /ru "${USERNAME:-Admin}" /f 2>/dev/null || true
    schtasks /run /tn "${PLIST_LABEL}" 2>/dev/null || true
    echo "Started wechat-claude-code daemon (Windows/TaskScheduler)"
    echo "NOTE: For production use, PM2 is recommended: pm2 start dist/main.js --name wechat-claude"
  fi
}

stop_service() {
  if [ "$OS_TYPE" = "macos" ]; then
    launchctl bootout "gui/$(id -u)/${PLIST_LABEL}" 2>/dev/null || true
    rm -f "$PLIST_PATH"
  elif [ "$OS_TYPE" = "linux" ]; then
    systemctl --user stop "${PLIST_LABEL}" 2>/dev/null || true
    systemctl --user disable "${PLIST_LABEL}" 2>/dev/null || true
    rm -f "$SYSTEMD_UNIT"
    systemctl --user daemon-reload
  elif [ "$OS_TYPE" = "windows" ]; then
    schtasks /end /tn "${PLIST_LABEL}" 2>/dev/null || true
    schtasks /delete /tn "${PLIST_LABEL}" /f 2>/dev/null || true
    rm -f "/tmp/${PLIST_LABEL}_start.bat"
  fi
  echo "Stopped wechat-claude-code daemon"
}

case "$1" in
  start)
    if is_loaded; then
      echo "Already running"
      exit 0
    fi
    start_service
    ;;
  stop)
    stop_service
    ;;
  restart)
    stop_service
    sleep 1
    start_service
    ;;
  status)
    if [ "$OS_TYPE" = "macos" ]; then
      if is_loaded; then
        pid=$(pgrep -f "dist/main.js start" 2>/dev/null | head -1)
        if [ -n "$pid" ]; then
          echo "Running (PID: $pid)"
        else
          echo "Loaded but not running"
        fi
      else
        echo "Not running"
      fi
    elif [ "$OS_TYPE" = "linux" ]; then
      if systemctl --user is-active --quiet "${PLIST_LABEL}" 2>/dev/null; then
        pid=$(systemctl --user show --property MainPID --value "${PLIST_LABEL}" 2>/dev/null)
        echo "Running (PID: $pid)"
      else
        echo "Not running"
      fi
    elif [ "$OS_TYPE" = "windows" ]; then
      if schtasks /query /tn "${PLIST_LABEL}" &>/dev/null; then
        echo "Task scheduled"
        tasklist /fi "IMAGENAME eq node.exe" 2>/dev/null | grep -q main.js && echo "Process running" || echo "Process not running"
      else
        echo "Not installed"
      fi
    fi
    ;;
  enable-linger)
    # 允许用户级服务开机自启（需要 sudo）
    if [ "$OS_TYPE" = "linux" ]; then
      echo "Enabling linger for $USER..."
      sudo loginctl enable-linger "$USER"
      echo "Done. Service will start at next boot."
    else
      echo "This command is only available on Linux"
    fi
    ;;
  logs)
    LOG_DIR="${DATA_DIR}/logs"
    if [ -d "$LOG_DIR" ]; then
      latest=$(ls -t "${LOG_DIR}"/bridge-*.log 2>/dev/null | head -1)
      if [ -n "$latest" ]; then
        tail -100 "$latest"
      else
        echo "No bridge logs found. Checking stdout/stderr:"
        for f in "${LOG_DIR}"/stdout.log "${LOG_DIR}"/stderr.log; do
          if [ -f "$f" ]; then
            echo "=== $(basename "$f") ==="
            tail -30 "$f"
          fi
        done
      fi
    else
      echo "No logs found"
    fi
    ;;
  *)
    echo "Usage: daemon.sh {start|stop|restart|status|logs}"
    echo "       daemon.sh enable-linger  # Enable boot start (Linux, needs sudo)"
    ;;
esac

# wechat-claude-code Windows Daemon Script
# Usage: .\daemon.ps1 {start|stop|restart|status}

param(
    [Parameter(Position=0)]
    [ValidateSet('start', 'stop', 'restart', 'status')]
    [string]$Action = 'start'
)

$ErrorActionPreference = 'Stop'
$SERVICE_NAME = "wechat-claude-code"
$PROJECT_DIR = Split-Path -Parent $PSScriptRoot
$LOG_DIR = "$env:USERPROFILE\.wechat-claude-code\logs"
$PID_FILE = "$env:USERPROFILE\.wechat-claude-code\daemon.pid"

function Get-ClaudeDaemonPid {
    if (Test-Path $PID_FILE) {
        $pid = Get-Content $PID_FILE -Raw -ErrorAction SilentlyContinue
        if ($pid -and (Get-Process -Id $pid -ErrorAction SilentlyContinue)) {
            return $pid
        }
    }
    return $null
}

switch ($Action) {
    'start' {
        $existing = Get-ClaudeDaemonPid
        if ($existing) {
            Write-Host "Already running (PID: $existing)"
            exit 0
        }

        if (-not (Test-Path $LOG_DIR)) {
            New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
        }

        $logFile = "$LOG_DIR\stdout.log"
        $errFile = "$LOG_DIR\stderr.log"

        $proc = Start-Process -FilePath "node" `
            -ArgumentList "dist/main.js", "start" `
            -WorkingDirectory $PROJECT_DIR `
            -PassThru `
            -RedirectStandardOutput $logFile `
            -RedirectStandardError $errFile `
            -WindowStyle Hidden

        $proc.Id | Set-Content $PID_FILE
        Write-Host "Started wechat-claude-code daemon (PID: $($proc.Id))"
    }

    'stop' {
        $pid = Get-ClaudeDaemonPid
        if ($pid) {
            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            Remove-Item $PID_FILE -Force -ErrorAction SilentlyContinue
            Write-Host "Stopped wechat-claude-code daemon"
        } else {
            Write-Host "Not running"
        }
    }

    'restart' {
        & $PSCommandPath stop
        Start-Sleep -Seconds 1
        & $PSCommandPath start
    }

    'status' {
        $pid = Get-ClaudeDaemonPid
        if ($pid) {
            Write-Host "Running (PID: $pid)"
        } else {
            Write-Host "Not running"
        }
    }
}

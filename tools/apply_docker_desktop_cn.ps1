# 以管理员 PowerShell 执行：
# powershell -ExecutionPolicy Bypass -File .\tools\apply_docker_desktop_cn.ps1

$ErrorActionPreference = "Stop"

$dockerRoot = "C:\Program Files\Docker\Docker"
$resourceDir = Join-Path $dockerRoot "frontend\resources"
$targetAsar = Join-Path $resourceDir "app.asar"
$backupAsar = Join-Path $resourceDir "app.asar.bak-20260409"
$sourceAsar = "C:\Users\Donki\UserData\Code\ZYKJ_MES\.tmp_runtime\docker_cn_work\app.asar.cn"
$dockerExe = Join-Path $dockerRoot "Docker Desktop.exe"

if (-not (Test-Path $sourceAsar)) {
    throw "未找到汉化产物：$sourceAsar"
}

$running = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
if ($running) {
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

if (-not (Test-Path $backupAsar)) {
    Copy-Item -LiteralPath $targetAsar -Destination $backupAsar
}

Copy-Item -LiteralPath $sourceAsar -Destination $targetAsar -Force
Start-Process -FilePath $dockerExe

Write-Host "Docker Desktop 汉化包已覆盖完成。" -ForegroundColor Green
Write-Host "原始备份路径：$backupAsar"

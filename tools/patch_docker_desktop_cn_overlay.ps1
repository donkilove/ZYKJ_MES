$ErrorActionPreference = "Stop"

function U([string]$s) {
    return [regex]::Unescape($s)
}

function Replace-QuotedLiteral {
    param(
        [string]$Content,
        [string]$Source,
        [string]$Target
    )

    $doubleQuotedSource = '"' + $Source + '"'
    $doubleQuotedTarget = '"' + $Target + '"'
    $singleQuotedSource = "'" + $Source + "'"
    $singleQuotedTarget = "'" + $Target + "'"

    $Content = $Content.Replace($doubleQuotedSource, $doubleQuotedTarget)
    $Content = $Content.Replace($singleQuotedSource, $singleQuotedTarget)
    return $Content
}

$workRoot = "C:\Users\Donki\UserData\Code\ZYKJ_MES\.tmp_runtime\docker_cn_overlay_work\app"
$bundleDir = Join-Path $workRoot "build\desktop-ui-build"
$outputAsar = "C:\Users\Donki\UserData\Code\ZYKJ_MES\.tmp_runtime\docker_cn_overlay_work\app.asar.cn.overlay"

if (-not (Test-Path $bundleDir)) {
    throw "Bundle directory not found: $bundleDir"
}

$replacements = @(
    @{ src = "Only show running containers"; dst = (U "\u4ec5\u663e\u793a\u6b63\u5728\u8fd0\u884c\u7684\u5bb9\u5668") }
    @{ src = "Show charts"; dst = (U "\u663e\u793a\u56fe\u8868") }
    @{ src = "Container CPU usage"; dst = (U "\u5bb9\u5668 CPU \u4f7f\u7528\u7387") }
    @{ src = "Container memory usage"; dst = (U "\u5bb9\u5668\u5185\u5b58\u4f7f\u7528\u7387") }
    @{ src = "Containers"; dst = (U "\u5bb9\u5668") }
    @{ src = "Images"; dst = (U "\u955c\u50cf") }
    @{ src = "Volumes"; dst = (U "\u5377") }
    @{ src = "Builds"; dst = (U "\u6784\u5efa") }
    @{ src = "Container ID"; dst = (U "\u5bb9\u5668 ID") }
    @{ src = "Port(s)"; dst = (U "\u7aef\u53e3") }
    @{ src = "Last started"; dst = (U "\u6700\u8fd1\u542f\u52a8") }
    @{ src = "Actions"; dst = (U "\u64cd\u4f5c") }
    @{ src = "Name"; dst = (U "\u540d\u79f0") }
    @{ src = "Image"; dst = (U "\u955c\u50cf") }
    @{ src = "Search"; dst = (U "\u641c\u7d22") }
)

$targets = @(
    (Join-Path $bundleDir "21803.bundle.rend.js"),
    (Join-Path $bundleDir "58530.bundle.rend.js")
)

foreach ($file in $targets) {
    if (-not (Test-Path $file)) {
        continue
    }

    $content = Get-Content -LiteralPath $file -Raw -Encoding UTF8
    $original = $content

    foreach ($pair in $replacements) {
        $content = Replace-QuotedLiteral -Content $content -Source $pair.src -Target $pair.dst
    }

    if ($content -ne $original) {
        Set-Content -LiteralPath $file -Value $content -Encoding UTF8 -NoNewline
    }
}

asar pack $workRoot $outputAsar
Write-Host "Overlay package generated: $outputAsar" -ForegroundColor Green

$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$siteRoot = Join-Path $workspaceRoot "docs\wiki-site"
$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
$nodePath = if ($nodeCommand) { $nodeCommand.Source } else { $null }

if (-not $nodePath -and $env:USERPROFILE) {
    $bundledNode = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
    if (Test-Path -LiteralPath $bundledNode) {
        $nodePath = $bundledNode
    }
}

if (-not $nodePath) {
    throw "Node.js не найден. Установите Node.js 20+ или запустите viewer из приложения Codex с доступным bundled runtime."
}

Write-Host "Almsth Wiki: http://127.0.0.1:4173"
Write-Host "Для остановки нажмите Ctrl+C."
& $nodePath (Join-Path $siteRoot "scripts\serve.mjs")
if ($LASTEXITCODE -ne 0) {
    throw "Almsth Wiki viewer завершился с кодом $LASTEXITCODE."
}

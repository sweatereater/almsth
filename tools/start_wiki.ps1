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
    throw "Node.js was not found. Install Node.js 20+ or run the viewer from Codex with its bundled runtime."
}

Write-Host "Almsth Wiki: http://127.0.0.1:4173"
Write-Host "Press Ctrl+C to stop."
& $nodePath (Join-Path $siteRoot "scripts\serve.mjs")
if ($LASTEXITCODE -ne 0) {
    throw "Almsth Wiki viewer exited with code $LASTEXITCODE."
}

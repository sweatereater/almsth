param(
    [string]$GodotPath = ""
)

$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = Join-Path $projectRoot ".tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
}

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

$outputDirectory = Join-Path $projectRoot "builds\windows"
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

& $GodotPath --headless --path $projectRoot --export-release "Windows Desktop" (Join-Path $outputDirectory "Almsth.exe")
exit $LASTEXITCODE

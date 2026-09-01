param(
    [string]$GodotPath = "",
    [ValidateSet("ru", "en")][string]$Locale = "ru",
    [switch]$AutoWalk
)
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectRoot ".tools/godot-4.7.2/Godot_v4.7.2-stable_win64.exe"
    if (-not (Test-Path -LiteralPath $GodotPath)) {
        $GodotPath = (Get-Command godot -ErrorAction Stop).Source
    }
}
$demoArgs = @("--path", $projectRoot, "res://scenes/demos/female_ghoul_walk.tscn", "--", "--locale=$Locale")
if ($AutoWalk) { $demoArgs += "--autowalk" }
& $GodotPath @demoArgs
exit $LASTEXITCODE

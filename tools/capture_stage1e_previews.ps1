[CmdletBinding()]
param(
    [string]$Output = "res://.tmp/stage1e-previews",
    [switch]$ValidateOnly,
    [switch]$CompatibilitySelfTest,
    [switch]$InvalidArgumentSelfTest,
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)]$UnsupportedArguments
)

if ($PSBoundParameters.ContainsKey('Help')) {
    throw "STAGE1E_CAPTURE_ARGUMENT_REJECTED: HELP_BOUND; no setup, cleanup, or Godot process was started"
}
if ($PSBoundParameters.ContainsKey('UnsupportedArguments')) {
    throw "STAGE1E_CAPTURE_ARGUMENT_REJECTED: UNSUPPORTED_ARGUMENTS_BOUND; no setup, cleanup, or Godot process was started"
}
$ErrorActionPreference = "Stop"
$argumentRejectionMarker = 'STAGE1E_CAPTURE_ARGUMENT_REJECTED'
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$fixedOutput = "res://.tmp/stage1e-previews"
$expectedRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ".tmp\stage1e-previews"))
$activeModes = @()
if ($ValidateOnly) { $activeModes += 'ValidateOnly' }
if ($CompatibilitySelfTest) { $activeModes += 'CompatibilitySelfTest' }
if ($InvalidArgumentSelfTest) { $activeModes += 'InvalidArgumentSelfTest' }
if ($Output -cne $fixedOutput) { throw "$argumentRejectionMarker`: OUTPUT_REJECTED; output must be $fixedOutput" }
if ($activeModes.Count -gt 1) { throw "$argumentRejectionMarker`: MODE_REJECTED; ValidateOnly, CompatibilitySelfTest, and InvalidArgumentSelfTest are globally mutually exclusive" }
function Register-GodotLaunch {
    if ($env:STAGE1E_CAPTURE_LAUNCH_AUDIT) {
        Add-Content -LiteralPath $env:STAGE1E_CAPTURE_LAUNCH_AUDIT -Value 'godot-launch'
    }
}
function Register-CaptureSetup {
    if ($env:STAGE1E_CAPTURE_SETUP_AUDIT) {
        Add-Content -LiteralPath $env:STAGE1E_CAPTURE_SETUP_AUDIT -Value 'capture-setup'
    }
}
function Get-CanonicalRepoRelativePath([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    $boundary = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($boundary, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "PREVIEW PATH REJECTED: path escapes canonical repository root: $full"
    }
    return $full.Substring($boundary.Length).Replace('\', '/')
}
function Get-Sha256([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($stream)
        return ([System.BitConverter]::ToString($hash).Replace('-', '').ToLowerInvariant())
    } finally { $stream.Dispose() }
}
function Get-Stage1ESourceHashes {
    $result = [ordered]@{}
    $inputs = [System.Collections.Generic.List[string]]::new()
    foreach ($relativeRoot in @('scripts', 'scenes', 'assets')) {
        $absoluteRoot = Join-Path $repoRoot $relativeRoot
        if (-not (Test-Path -LiteralPath $absoluteRoot -PathType Container)) { throw "Capture source root missing: $relativeRoot" }
        foreach ($file in Get-ChildItem -LiteralPath $absoluteRoot -Recurse -File -Force | Sort-Object FullName) { $inputs.Add($file.FullName) }
    }
    foreach ($relative in @('project.godot', 'tests/capture_stage1e_preview.gd', 'tools/capture_stage1e_previews.ps1', 'tools/package_body_skill_icons.py', 'tools/patch_stage1e_camp_art.py', 'tools/prepare_nightly_camp_assets.py', 'tools/verify_stage1c_protected_assets.py', 'art/skills/body-icons/2026-09-01/PROMPTS.md', 'art/skills/body-icons/2026-09-01/manifest.json', 'assets/art/camp-2026-09-01/manifest.json', '.tmp/stage1e-before-evidence/camp-record-player.png', '.tmp/stage1e-before-evidence/camp-workbench.png')) {
        $absolute = Join-Path $repoRoot $relative
        if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) { throw "Capture source input missing: $relative" }
        $inputs.Add($absolute)
    }
    foreach ($input in $inputs | Sort-Object -Unique) {
        $key = Get-CanonicalRepoRelativePath $input
        if ($key.Contains('../') -or $key.StartsWith('/') -or $key.StartsWith('.godot/')) { throw "Capture source key rejected: $key" }
        $result[$key] = Get-Sha256 $input
    }
    return $result
}
# Valid diagnostic modes receive the same private user-data environment as a
# capture. Unsupported arguments returned above still reach no filesystem
# setup, cleanup, or child process.
Register-CaptureSetup
$isolatedRoot = Join-Path $repoRoot ('.tmp\nightly\stage1e-capture-{0}' -f $PID)
foreach ($leaf in @('environment\appdata', 'environment\localappdata', 'environment\temp')) { New-Item -ItemType Directory -Force -Path (Join-Path $isolatedRoot $leaf) | Out-Null }
$env:APPDATA = Join-Path $isolatedRoot 'environment\appdata'
$env:LOCALAPPDATA = Join-Path $isolatedRoot 'environment\localappdata'
$env:TEMP = Join-Path $isolatedRoot 'environment\temp'
$env:TMP = $env:TEMP
$env:ALMSTH_NIGHTLY_ROOT = $isolatedRoot
if ($Output -cne $fixedOutput) { throw "$argumentRejectionMarker`: OUTPUT_REJECTED; output must be $fixedOutput" }
if ($activeModes.Count -gt 1) { throw "$argumentRejectionMarker`: MODE_REJECTED; ValidateOnly, CompatibilitySelfTest, and InvalidArgumentSelfTest are globally mutually exclusive" }
if ($CompatibilitySelfTest) {
	if (-not $env:APPDATA.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $env:ALMSTH_NIGHTLY_ROOT -ne $isolatedRoot) { throw 'Compatibility self-test did not receive workspace-private environment' }
    $inside = Join-Path $repoRoot '.tmp\stage1e-previews\compatibility-sentinel.png'
    if ((Get-CanonicalRepoRelativePath $inside) -ne '.tmp/stage1e-previews/compatibility-sentinel.png') { throw 'PS5 canonical relative-path self-test failed for in-root path' }
    $escaped = Join-Path (Split-Path -Parent $repoRoot) 'almsth-sibling\escaped.png'
    try { [void](Get-CanonicalRepoRelativePath $escaped); throw 'PS5 canonical relative-path self-test failed to reject sibling' } catch { if ($_.Exception.Message -notlike 'PREVIEW PATH REJECTED*') { throw } }
    Write-Host 'STAGE 1E CAPTURE PS5 COMPATIBILITY SELF-TEST PASSED: canonical containment/relative paths'
    exit 0
}
if ($InvalidArgumentSelfTest) {
	if (-not $env:TEMP.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase) -or $env:ALMSTH_NIGHTLY_ROOT -ne $isolatedRoot) { throw 'Invalid-argument self-test did not receive workspace-private environment' }
    # Exercise the public parser in a child process. The sentinel and launch/
    # setup audits are outside the disposable capture root, so a bad argument
    # cannot be masked by normal cleanup.
    $sentinelRoot = Join-Path $repoRoot '.tmp\stage1e-wrapper-invalid-sentinel'
    New-Item -ItemType Directory -Force -Path $sentinelRoot | Out-Null
    $sentinel = Join-Path $sentinelRoot 'outside-sentinel.txt'
    $launchAudit = Join-Path $sentinelRoot 'launch-count.txt'
    $setupAudit = Join-Path $sentinelRoot 'setup-count.txt'
    Set-Content -LiteralPath $sentinel -Value 'must-survive' -NoNewline
    Remove-Item -LiteralPath $launchAudit -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $setupAudit -Force -ErrorAction SilentlyContinue
    $previousLaunchAudit = $env:STAGE1E_CAPTURE_LAUNCH_AUDIT
    $previousSetupAudit = $env:STAGE1E_CAPTURE_SETUP_AUDIT
    $env:STAGE1E_CAPTURE_LAUNCH_AUDIT = $launchAudit
    $env:STAGE1E_CAPTURE_SETUP_AUDIT = $setupAudit
    try {
        $escapedScriptPath = $PSCommandPath.Replace("'", "''")
        $helpFalseExpression = '$boundParameters = @{{Help = $false}}; & ''{0}'' @boundParameters' -f $escapedScriptPath
        $unsupportedEmptyExpression = '$boundParameters = @{{UnsupportedArguments = @()}}; & ''{0}'' @boundParameters' -f $escapedScriptPath
        $invalidCases = @(
            [pscustomobject]@{ Name = 'help-cli'; Arguments = @('-Help'); Expression = $null; ExpectedMarker = "$argumentRejectionMarker`: HELP_BOUND" },
            [pscustomobject]@{ Name = 'help-false-bound'; Arguments = @(); Expression = $helpFalseExpression; ExpectedMarker = "$argumentRejectionMarker`: HELP_BOUND" },
            [pscustomobject]@{ Name = 'unsupported-empty-bound'; Arguments = @(); Expression = $unsupportedEmptyExpression; ExpectedMarker = "$argumentRejectionMarker`: UNSUPPORTED_ARGUMENTS_BOUND" },
            [pscustomobject]@{ Name = 'unknown-cli'; Arguments = @('-Bogus'); Expression = $null; ExpectedMarker = "$argumentRejectionMarker`: UNSUPPORTED_ARGUMENTS_BOUND" },
            [pscustomobject]@{ Name = 'positional-cli'; Arguments = @('unexpected-positional'); Expression = $null; ExpectedMarker = "$argumentRejectionMarker`: OUTPUT_REJECTED" },
            [pscustomobject]@{ Name = 'compatibility-bad-output'; Arguments = @('-CompatibilitySelfTest', '-Output', 'res://.tmp/evil'); Expression = $null; ExpectedMarker = "$argumentRejectionMarker`: OUTPUT_REJECTED" },
            [pscustomobject]@{ Name = 'invalid-args-bad-output'; Arguments = @('-InvalidArgumentSelfTest', '-Output', 'res://.tmp/../evil'); Expression = $null; ExpectedMarker = "$argumentRejectionMarker`: OUTPUT_REJECTED" },
            [pscustomobject]@{ Name = 'validate-compatibility'; Arguments = @('-ValidateOnly', '-CompatibilitySelfTest'); Expression = $null; ExpectedMarker = "$argumentRejectionMarker`: MODE_REJECTED" },
            [pscustomobject]@{ Name = 'validate-invalid-args'; Arguments = @('-ValidateOnly', '-InvalidArgumentSelfTest'); Expression = $null; ExpectedMarker = "$argumentRejectionMarker`: MODE_REJECTED" },
            [pscustomobject]@{ Name = 'compatibility-invalid-args'; Arguments = @('-CompatibilitySelfTest', '-InvalidArgumentSelfTest'); Expression = $null; ExpectedMarker = "$argumentRejectionMarker`: MODE_REJECTED" },
            [pscustomobject]@{ Name = 'all-modes'; Arguments = @('-ValidateOnly', '-CompatibilitySelfTest', '-InvalidArgumentSelfTest'); Expression = $null; ExpectedMarker = "$argumentRejectionMarker`: MODE_REJECTED" }
        )
        foreach ($invalidCase in $invalidCases) {
            # Use a real child process rather than PowerShell's native-command
            # stream bridge. Splat-only binding cases use an encoded expression
            # so PowerShell reaches this wrapper body instead of rejecting the
            # switch syntax in its native -File argument transformer.
            $child = [System.Diagnostics.Process]::new()
            $child.StartInfo.FileName = (Get-Command powershell.exe -ErrorAction Stop).Source
            if ([string]::IsNullOrEmpty([string]$invalidCase.Expression)) {
                $childArguments = @(
                    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath
                ) + @($invalidCase.Arguments)
            } else {
                $encodedExpression = [Convert]::ToBase64String(
                    [Text.Encoding]::Unicode.GetBytes([string]$invalidCase.Expression)
                )
                $childArguments = @(
                    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encodedExpression
                )
            }
            $quoted = $childArguments | ForEach-Object { '"' + ([string]$_).Replace('"', '\"') + '"' }
            $child.StartInfo.Arguments = $quoted -join ' '
            $child.StartInfo.UseShellExecute = $false
            $child.StartInfo.RedirectStandardOutput = $true
            $child.StartInfo.RedirectStandardError = $true
            [void]$child.Start()
            $childStdout = $child.StandardOutput.ReadToEnd()
            $childStderr = $child.StandardError.ReadToEnd()
            $child.WaitForExit()
            $childOutput = $childStdout + [Environment]::NewLine + $childStderr
            if ($child.ExitCode -eq 0) {
                throw ("Invalid argument unexpectedly succeeded: " + $invalidCase.Name)
            }
            if (-not $childOutput.Contains([string]$invalidCase.ExpectedMarker)) {
                $childDiagnostic = ($childOutput.Trim() -replace '\s+', ' ')
                throw ("Invalid argument did not reach its wrapper rejection marker: " + $invalidCase.Name + "; child output: " + $childDiagnostic)
            }
            if (
                (Get-Content -LiteralPath $sentinel -Raw) -ne 'must-survive' -or
                (Test-Path -LiteralPath $launchAudit) -or
                (Test-Path -LiteralPath $setupAudit)
            ) {
                throw ("Invalid argument reached capture setup, cleanup, or Godot: " + $invalidCase.Name)
            }
        }
    }
    finally {
        $env:STAGE1E_CAPTURE_LAUNCH_AUDIT = $previousLaunchAudit
        $env:STAGE1E_CAPTURE_SETUP_AUDIT = $previousSetupAudit
    }
    if (
        (Get-Content -LiteralPath $sentinel -Raw) -ne 'must-survive' -or
        (Test-Path -LiteralPath $launchAudit) -or
        (Test-Path -LiteralPath $setupAudit)
    ) { throw 'Invalid argument touched sentinel, reached capture setup, or launched Godot' }
    Write-Host 'STAGE 1E CAPTURE INVALID-ARG SELF-TEST PASSED: zero setup mutations; zero launches; outside sentinel unchanged'
    exit 0
}
if ($Output -cne $fixedOutput) { throw "$argumentRejectionMarker`: OUTPUT_REJECTED; output must be $fixedOutput" }
$resolved = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Output.Substring('res://'.Length).Replace('/', '\')))
if (-not [System.StringComparer]::OrdinalIgnoreCase.Equals($resolved, $expectedRoot)) {
    throw "$argumentRejectionMarker`: OUTPUT_REJECTED; output must resolve exactly to $fixedOutput"
}
$godot = Join-Path $repoRoot ".tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { throw "Compatible Godot executable not found: $godot" }
Register-CaptureSetup
$isolatedRoot = Join-Path $repoRoot ('.tmp\nightly\stage1e-capture-{0}' -f $PID)
foreach ($leaf in @('environment\appdata', 'environment\localappdata', 'environment\temp')) { New-Item -ItemType Directory -Force -Path (Join-Path $isolatedRoot $leaf) | Out-Null }
$env:APPDATA = Join-Path $isolatedRoot 'environment\appdata'
$env:LOCALAPPDATA = Join-Path $isolatedRoot 'environment\localappdata'
$env:TEMP = Join-Path $isolatedRoot 'environment\temp'
$env:TMP = $env:TEMP
$env:ALMSTH_NIGHTLY_ROOT = $isolatedRoot
$privateRuntimeDir = Join-Path $isolatedRoot 'runtime_sc'
New-Item -ItemType Directory -Force -Path $privateRuntimeDir | Out-Null
$privateGodot = Join-Path $privateRuntimeDir 'Godot_v4.7.2-stable_win64_console.exe'
foreach ($runtimeName in @('Godot_v4.7.2-stable_win64_console.exe', 'Godot_v4.7.2-stable_win64.exe')) {
    Copy-Item -LiteralPath (Join-Path $repoRoot ('.tools\godot-4.7.2\' + $runtimeName)) -Destination (Join-Path $privateRuntimeDir $runtimeName) -Force
}
Set-Content -LiteralPath (Join-Path $privateRuntimeDir '_sc_') -Value 'Stage1E private capture runtime' -Encoding utf8
$godot = $privateGodot
$beforeRoot = Join-Path $repoRoot ".tmp\stage1e-before-evidence"
New-Item -ItemType Directory -Force -Path $beforeRoot | Out-Null
function Export-GitBinary([string]$Spec, [string]$Destination) {
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo.FileName = "git"
    $process.StartInfo.Arguments = "show $Spec"
    $process.StartInfo.WorkingDirectory = $repoRoot
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    [void]$process.Start()
    $stream = [System.IO.File]::Open($Destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try { $process.StandardOutput.BaseStream.CopyTo($stream) } finally { $stream.Dispose() }
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "Could not reconstruct immutable pre-Stage1E evidence: $Spec" }
}
if (-not $ValidateOnly) {
    Export-GitBinary "HEAD:assets/art/camp-2026-09-01/camp-record-player.png" (Join-Path $beforeRoot "camp-record-player.png")
    Export-GitBinary "HEAD:assets/art/camp-2026-09-01/camp-workbench.png" (Join-Path $beforeRoot "camp-workbench.png")
	# Refresh only the editor import cache; this never exports or publishes an
	# artifact. The capture runner then hashes the *live imported* alpha planes.
	Register-GodotLaunch; & $godot --headless --editor --path $repoRoot --quit
	if ($LASTEXITCODE -ne 0) { throw "Godot editor import refresh failed" }
}
Push-Location $repoRoot
try {
    if (-not $ValidateOnly) {
        # No --headless: the runner rejects a dummy/empty viewport by design.
        Register-GodotLaunch; & $godot --path . --script res://tests/capture_stage1e_preview.gd
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    $manifestPath = Join-Path $expectedRoot "manifest.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $expectedSources = Get-Stage1ESourceHashes
    $actualSources = [ordered]@{}
    foreach ($property in $manifest.source_hashes.psobject.Properties) {
        $key = [string]$property.Name
        if ($key.Contains('..') -or $key.StartsWith('/') -or $key.StartsWith('\')) { throw "Capture manifest source key rejected: $key" }
        $actualSources[$key] = [string]$property.Value
    }
    $sourceMismatch = [System.Collections.Generic.List[string]]::new()
    foreach ($key in $expectedSources.Keys) { if (-not $actualSources.Contains($key) -or $actualSources[$key] -ne $expectedSources[$key]) { $sourceMismatch.Add($key) } }
    foreach ($key in $actualSources.Keys) { if (-not $expectedSources.Contains($key)) { $sourceMismatch.Add($key) } }
    if ($sourceMismatch.Count -gt 0) { throw ('Capture source-hash closure is missing, stale, or contains an extra input: ' + (($sourceMismatch | Sort-Object -Unique | Select-Object -First 8) -join ', ')) }
    $expected = 4 * ((13 * 6) + 7) + 2 * (47 + 27)
    if ($manifest.stage -ne "1E" -or $manifest.expected_capture_count -ne $expected -or $manifest.capture_count -ne $expected -or @($manifest.captures).Count -ne $expected) {
        throw "Stage1E capture matrix mismatch"
    }
    $paths = @($manifest.captures | ForEach-Object { $_.path })
    $pngs = @(Get-ChildItem -LiteralPath $expectedRoot -Filter '*.png' -File | ForEach-Object { Get-CanonicalRepoRelativePath $_.FullName })
    if (@($paths | Sort-Object -Unique).Count -ne $expected -or (Compare-Object ($paths | Sort-Object) ($pngs | Sort-Object))) { throw "Preview matrix contains stale, missing, or duplicate PNGs" }
    $profiles = @($manifest.captures | Group-Object { "$($_.locale)-$($_.width)x$($_.height)" })
    if ($profiles.Count -ne 4 -or @($profiles | Where-Object { $_.Name -like 'ru-*' -and $_.Count -ne 85 }).Count -ne 0 -or @($profiles | Where-Object { $_.Name -like 'en-*' -and $_.Count -ne 159 }).Count -ne 0) { throw "Profile coverage must be 85 RU and 159 EN captures at both resolutions" }
    $lunge = @($manifest.captures | Where-Object { $_.scenario -like 'lunge-*' })
    $forensics = @($manifest.captures | Where-Object { $_.scenario -like 'forensic-*' })
    $sheets = @($manifest.captures | Where-Object { $_.scenario -like 'body-icons-sheet-*' })
    if ($lunge.Count -ne 94 -or $forensics.Count -ne 48 -or $sheets.Count -ne 6) { throw "Stage1E category coverage mismatch: lunge=$($lunge.Count), forensic=$($forensics.Count), sheets=$($sheets.Count)" }
    foreach ($profile in $profiles) {
        foreach ($campId in @($manifest.camp_ids)) {
            $normal = @($profile.Group | Where-Object { $_.scenario -eq "camp-$campId-normal" })
            $disabled = @($profile.Group | Where-Object { $_.scenario -eq "camp-$campId-disabled_unbuilt" })
            if ($normal.Count -ne 1 -or $disabled.Count -ne 1 -or $normal[0].sha256 -eq $disabled[0].sha256) {
                throw "Disabled/unbuilt camp capture must differ from normal built prop: $campId $($profile.Name)"
            }
        }
    }
    foreach ($capture in $manifest.captures) {
        $path = Join-Path $repoRoot ($capture.path.Replace('/', '\'))
        if ((Get-Sha256 $path) -ne $capture.sha256) { throw "Preview SHA mismatch: $($capture.path)" }
    }
    Write-Host "STAGE 1E PREVIEW MANIFEST VALIDATED: $expected real-render PNGs; containment/freshness/SHA PASS"
}
finally { Pop-Location }

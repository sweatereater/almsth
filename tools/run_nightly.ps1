#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Full', 'Targeted', 'Settings', 'Fail', 'Timeout')]
    [string]$Mode = 'Full',
    [ValidateCount(1, 3)]
    [int[]]$Seeds = @(812, 10007, 90001),
    [ValidateRange(5, 240)]
    [int]$PhaseTimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runId = '{0}-{1}-{2}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $PID, ([guid]::NewGuid().ToString('N').Substring(0, 8))
$runRoot = Join-Path $projectRoot ".tmp\nightly\$runId"
$runtimeRoot = Join-Path $runRoot 'runtime'
$sourceRuntime = Join-Path $projectRoot '.tools\godot-4.7.2'
$executableName = 'Godot_v4.7.2-stable_win64.exe'
$results = [System.Collections.Generic.List[object]]::new()
$overallExit = 0
$protectedRoots = @(
    (Join-Path $sourceRuntime 'editor_data')
)

function Get-ProtectedManifest {
    $entries = foreach ($directory in $protectedRoots) {
        if (Test-Path -LiteralPath $directory) {
            foreach ($file in Get-ChildItem -LiteralPath $directory -Recurse -File -Force | Sort-Object FullName) {
                [ordered]@{ path = $file.FullName; length = $file.Length; last_write_time_utc = $file.LastWriteTimeUtc.ToString('O'); sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
            }
        }
    }
    return @($entries)
}

function Write-JsonFile([string]$Path, $Value) {
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Invoke-NightlyPhase([string]$Name, [string]$Script, [string[]]$UserArguments, [string]$PassMarker, [int]$TimeoutSeconds) {
    $phaseRoot = Join-Path $runRoot $Name
    New-Item -ItemType Directory -Path $phaseRoot | Out-Null
    $arguments = @('--headless', '--path', $projectRoot, '--log-file', (Join-Path $phaseRoot 'engine.log'), '--script', $Script)
    if ($UserArguments.Count -gt 0) { $arguments += @('--') + $UserArguments }
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = Join-Path $runtimeRoot $executableName
    $info.WorkingDirectory = $projectRoot
    foreach ($argument in $arguments) { $info.ArgumentList.Add($argument) }
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($key in $privateEnvironment.Keys) { $info.Environment[$key] = $privateEnvironment[$key] }
    Write-JsonFile (Join-Path $phaseRoot 'command.json') ([ordered]@{
        executable = $info.FileName; arguments = $arguments; working_directory = $projectRoot
        environment = $privateEnvironment; timeout_seconds = $TimeoutSeconds; expected_marker = $PassMarker
    })
    $record = [ordered]@{ phase = $Name; pid = $null; exit_code = $null; timeout = $false; owned_process_stopped = $false; passed = $false; errors = @(); known_warnings = @(); logs = $phaseRoot }
    $ownedProcess = $null
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $ownedProcess = [System.Diagnostics.Process]::Start($info)
        $record.pid = $ownedProcess.Id
        $stdoutTask = $ownedProcess.StandardOutput.ReadToEndAsync()
        $stderrTask = $ownedProcess.StandardError.ReadToEndAsync()
        if (-not $ownedProcess.WaitForExit($TimeoutSeconds * 1000)) {
            $record.timeout = $true
            $ownedProcess.Kill($true)
            if (-not $ownedProcess.WaitForExit(5000)) { throw 'Owned process did not stop after timeout' }
        }
        $record.owned_process_stopped = $ownedProcess.HasExited
        $record.exit_code = $ownedProcess.ExitCode
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $stdout | Set-Content -LiteralPath (Join-Path $phaseRoot 'stdout.log') -Encoding utf8
        $stderr | Set-Content -LiteralPath (Join-Path $phaseRoot 'stderr.log') -Encoding utf8
        $engineLog = Join-Path $phaseRoot 'engine.log'
        $combined = $stdout + "`n" + $stderr
        if (Test-Path -LiteralPath $engineLog) { $combined += "`n" + (Get-Content -LiteralPath $engineLog -Raw) }
        foreach ($line in ($combined -split '\r?\n' | Select-Object -Unique)) {
            if ($line -ceq 'ERROR: Failed to read the root certificate store.') {
                $record.known_warnings += $line
            } elseif ($line -match '(?i)\bERROR\b|ParseError') {
                $record.errors += $line
            }
        }
        if ($record.timeout) { $record.errors += "Phase exceeded $TimeoutSeconds seconds" }
        if ($record.exit_code -ne 0) { $record.errors += "Engine exited with code $($record.exit_code)" }
        if (-not $combined.Contains($PassMarker)) { $record.errors += "Missing expected marker: $PassMarker" }
        $record.passed = $record.errors.Count -eq 0
    } catch {
        $record.errors += $_.Exception.Message
    } finally {
        if ($null -ne $ownedProcess) {
            if (-not $ownedProcess.HasExited) { $ownedProcess.Kill($true); $ownedProcess.WaitForExit(5000) | Out-Null }
            $record.owned_process_stopped = $ownedProcess.HasExited
            $ownedProcess.Dispose()
        }
        $record.elapsed_seconds = [Math]::Round($clock.Elapsed.TotalSeconds, 3)
        Write-JsonFile (Join-Path $phaseRoot 'result.json') $record
        $results.Add($record)
        Write-Host ('{0}: {1} ({2}s), logs: {3}' -f $Name, $(if ($record.passed) {'PASS'} else {'FAIL'}), $record.elapsed_seconds, $phaseRoot)
    }
    if (-not $record.passed) { throw "Nightly phase failed: $Name" }
}

New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
$before = Get-ProtectedManifest
Write-JsonFile (Join-Path $runRoot 'protected-before.json') $before
$privateEnvironment = [ordered]@{
    APPDATA = Join-Path $runRoot 'environment\appdata'
    LOCALAPPDATA = Join-Path $runRoot 'environment\localappdata'
    TEMP = Join-Path $runRoot 'environment\temp'
    TMP = Join-Path $runRoot 'environment\temp'
    ALMSTH_NIGHTLY_ROOT = $runRoot
}
foreach ($directory in @($privateEnvironment.APPDATA, $privateEnvironment.LOCALAPPDATA, $privateEnvironment.TEMP)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
Write-Host "NIGHTLY RUN ROOT: $runRoot"
try {
    $binaryManifest = foreach ($name in @($executableName, 'Godot_v4.7.2-stable_win64_console.exe')) {
        $source = Join-Path $sourceRuntime $name
        $destination = Join-Path $runtimeRoot $name
        Copy-Item -LiteralPath $source -Destination $destination
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $copyHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        if ($sourceHash -ne $copyHash) { throw "Runtime copy mismatch: $name" }
        [ordered]@{ source = $source; copy = $destination; sha256 = $copyHash }
    }
    Set-Content -LiteralPath (Join-Path $runtimeRoot '_sc_') -Value 'Nightly private editor data' -Encoding utf8
    Write-JsonFile (Join-Path $runRoot 'runtime.json') $binaryManifest
    if ($Mode -in @('Fail', 'Timeout')) {
        Invoke-NightlyPhase "probe-$Mode" 'res://tests/run_nightly_scenarios.gd' @("--phase=$($Mode.ToLowerInvariant())", '--seed=812') 'NIGHTLY PHASE PASSED' $(if ($Mode -eq 'Timeout') {2} else {10})
    } else {
        Invoke-NightlyPhase 'settings' 'res://tests/run_nightly_scenarios.gd' @('--phase=settings', '--seed=812') 'NIGHTLY PHASE PASSED' $PhaseTimeoutSeconds
        if ($Mode -ne 'Settings') {
            foreach ($seed in $Seeds) {
                foreach ($phase in @('prepare', 'resume', 'death-resume', 'auto')) {
                    Invoke-NightlyPhase "$seed-$phase" 'res://tests/run_nightly_scenarios.gd' @("--phase=$phase", "--seed=$seed") 'NIGHTLY PHASE PASSED' $PhaseTimeoutSeconds
                }
            }
        }
        if ($Mode -eq 'Full') {
            Invoke-NightlyPhase 'smoke' 'res://tests/smoke_test.gd' @() 'SMOKE TEST PASSED' $PhaseTimeoutSeconds
            Invoke-NightlyPhase 'soak' 'res://tests/soak_test.gd' @() 'SOAK TEST PASSED' $PhaseTimeoutSeconds
        }
    }
} catch {
    $overallExit = 1
    Write-Warning $_.Exception.Message
} finally {
    $after = Get-ProtectedManifest
    Write-JsonFile (Join-Path $runRoot 'protected-after.json') $after
    $protectedUnchanged = (ConvertTo-Json -InputObject $before -Depth 8 -Compress) -ceq (ConvertTo-Json -InputObject $after -Depth 8 -Compress)
    if (-not $protectedUnchanged) { $overallExit = 1; Write-Warning 'Protected user data changed; see before/after manifests' }
    Write-JsonFile (Join-Path $runRoot 'summary.json') ([ordered]@{ mode = $Mode; seeds = $Seeds; phase_timeout_seconds = $PhaseTimeoutSeconds; scenario_action_limit = 5000; auto_timeout_seconds = 90; exit_code = $overallExit; protected_data_unchanged = $protectedUnchanged; phases = @($results.ToArray()) })
    $lines = @("# Nightly $runId", '', "Mode: $Mode. Exit: $overallExit. Protected data unchanged: $protectedUnchanged.", '', '| Phase | Result | Exit | Seconds | Logs |', '|---|---|---:|---:|---|')
    foreach ($result in $results) { $lines += "| $($result.phase) | $($result.passed) | $($result.exit_code) | $($result.elapsed_seconds) | $($result.logs) |" }
    $lines | Set-Content -LiteralPath (Join-Path $runRoot 'summary.md') -Encoding utf8
    Write-Host "NIGHTLY SUMMARY: $(Join-Path $runRoot 'summary.md')"
}
exit $overallExit

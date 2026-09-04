param(
    [string]$Output = "res://.tmp/stage1c-previews",
    [switch]$ContainmentSelfTest
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$fixedOutput = 'res://.tmp/stage1c-previews'
$canonicalPreviewRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot '.tmp\stage1c-previews'))

function Resolve-PreviewOutputPath {
    param([Parameter(Mandatory)][string]$Value)

    if (-not $Value.StartsWith('res://', [System.StringComparison]::Ordinal)) {
        throw "PREVIEW OUTPUT REJECTED: output must be the fixed res:// preview root"
    }
    $relative = $Value.Substring('res://'.Length).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $resolved = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $relative))
    if ($Value -cne $fixedOutput -or -not [System.StringComparer]::OrdinalIgnoreCase.Equals($resolved, $canonicalPreviewRoot)) {
        throw "PREVIEW OUTPUT REJECTED: output must resolve exactly to $fixedOutput"
    }
    return $resolved
}

function Invoke-ContainmentSelfTest {
    $tmpRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot '.tmp'))
    $tmpBoundary = $tmpRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $cases = @(
        [ordered]@{
            Name = 'traversal'
            Leaf = "stage1d-preview-containment-traversal-$PID"
            Output = "res://.tmp/stage1c-previews/../stage1d-preview-containment-traversal-$PID"
        },
        [ordered]@{
            Name = 'sibling-prefix'
            Leaf = "stage1c-previews-sibling-$PID"
            Output = "res://.tmp/stage1c-previews-sibling-$PID"
        }
    )
    $testDirectories = @()
    try {
        foreach ($case in $cases) {
            $testDirectory = [System.IO.Path]::GetFullPath((Join-Path $tmpRoot $case.Leaf))
            if (-not $testDirectory.StartsWith($tmpBoundary, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Containment self-test target escaped .tmp: $testDirectory"
            }
            $testDirectories += $testDirectory
            New-Item -ItemType Directory -Path $testDirectory -Force | Out-Null
            $sentinel = Join-Path $testDirectory 'escaped-sentinel.png'
            Set-Content -LiteralPath $sentinel -Value "stage1d containment sentinel: $($case.Name)" -NoNewline

            $wrapperOutput = & pwsh -NoProfile -File $PSCommandPath -Output $case.Output 2>&1
            $wrapperExit = $LASTEXITCODE
            if ($wrapperExit -eq 0 -or -not (($wrapperOutput | Out-String).Contains('PREVIEW OUTPUT REJECTED'))) {
                throw "Wrapper failed to reject $($case.Name) output before launch: exit=$wrapperExit"
            }
            if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
                throw "Wrapper cleanup reached escaped $($case.Name) sentinel"
            }

            $godot = Join-Path $repoRoot '.tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
            if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
                throw "Compatible Godot executable not found: $godot"
            }
            $captureOutput = & $godot --headless --path $repoRoot --script res://tests/capture_stage1c_ui_preview.gd -- "--output=$($case.Output)" 2>&1
            $captureExit = $LASTEXITCODE
            if ($captureExit -eq 0 -or -not (($captureOutput | Out-String).Contains('PREVIEW OUTPUT REJECTED'))) {
                throw "Capture runner failed to reject $($case.Name) output before cleanup: exit=$captureExit"
            }
            if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
                throw "Capture cleanup reached escaped $($case.Name) sentinel"
            }
        }
        Write-Host 'STAGE 1D PREVIEW CONTAINMENT TEST PASSED: traversal/sibling rejected; sentinels survived'
    }
    finally {
        foreach ($testDirectory in $testDirectories) {
            $resolved = [System.IO.Path]::GetFullPath($testDirectory)
            if ($resolved.StartsWith($tmpBoundary, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolved)) {
                Remove-Item -LiteralPath $resolved -Recurse -Force
            }
        }
    }
}

if ($ContainmentSelfTest) {
    Invoke-ContainmentSelfTest
    exit 0
}

$outputPath = Resolve-PreviewOutputPath -Value $Output
$Output = $fixedOutput
Invoke-ContainmentSelfTest
$godot = Join-Path $repoRoot ".tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
    throw "Compatible Godot executable not found: $godot"
}

Push-Location $repoRoot
try {
    & $godot --path . --script res://tests/capture_stage1c_ui_preview.gd -- "--output=$Output"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $manifestPath = Join-Path $outputPath "manifest.json"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.stage -ne '1D' -or $manifest.expected_capture_count -ne 228 -or
        $manifest.capture_count -ne 228 -or @($manifest.captures).Count -ne 228) {
        throw "Stage 1D capture contract mismatch: stage=$($manifest.stage), expected=$($manifest.expected_capture_count), actual=$($manifest.capture_count), records=$(@($manifest.captures).Count)"
    }
    $manifestPaths = @($manifest.captures | ForEach-Object { $_.path })
    $pngPaths = @(Get-ChildItem -LiteralPath $outputPath -Filter '*.png' -File | ForEach-Object {
        [System.IO.Path]::GetRelativePath($repoRoot, $_.FullName).Replace('\', '/')
    })
    if (@($manifestPaths | Sort-Object -Unique).Count -ne $manifest.expected_capture_count) {
        throw "Manifest contains duplicate or missing capture paths"
    }
    if (Compare-Object ($manifestPaths | Sort-Object) ($pngPaths | Sort-Object)) {
        throw "Stale or unmanifested PNGs exist in $outputPath"
    }
    $profileGroups = @($manifest.captures | Group-Object { "$($_.locale)-$($_.width)x$($_.height)" })
    if ($profileGroups.Count -ne 4 -or @($profileGroups | Where-Object { $_.Count -ne 57 }).Count -ne 0) {
        throw "Every RU/EN 1280/960 profile must contain exactly 57 scenarios"
    }

    Add-Type -AssemblyName System.Drawing
    foreach ($capture in $manifest.captures) {
        $capturePath = Join-Path $repoRoot ($capture.path.Replace('/', '\'))
        $actualHash = (Get-FileHash -LiteralPath $capturePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $capture.sha256) {
            throw "Capture SHA-256 mismatch: $($capture.path)"
        }
        $bitmap = [System.Drawing.Image]::FromFile($capturePath)
        try {
            if ($bitmap.Width -ne $capture.width -or $bitmap.Height -ne $capture.height) {
                throw "Capture dimension mismatch: $($capture.path)"
            }
        }
        finally {
            $bitmap.Dispose()
        }
    }

    $inputRoots = @(
        (Join-Path $repoRoot 'scripts'),
        (Join-Path $repoRoot 'scenes'),
        (Join-Path $repoRoot 'assets')
    )
    $expectedInputs = @($inputRoots | ForEach-Object {
        Get-ChildItem -LiteralPath $_ -Recurse -File
    } | ForEach-Object {
        [System.IO.Path]::GetRelativePath($repoRoot, $_.FullName).Replace('\', '/')
    })
    $expectedInputs += @(
        'project.godot',
        'tests/capture_stage1c_ui_preview.gd',
        'tools/capture_stage1c_previews.ps1'
    )
    $manifestInputs = @($manifest.source_hashes.PSObject.Properties.Name)
    if (Compare-Object ($expectedInputs | Sort-Object -Unique) ($manifestInputs | Sort-Object -Unique)) {
        throw "Preview source-hash coverage is incomplete or contains stale inputs"
    }
    foreach ($property in $manifest.source_hashes.PSObject.Properties) {
        $sourcePath = Join-Path $repoRoot ($property.Name.Replace('/', '\'))
        $actualHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $property.Value) {
            throw "Preview source hash is stale: $($property.Name)"
        }
    }
    Write-Host "STAGE 1D PREVIEW MANIFEST VALIDATED: $($manifest.capture_count) PNGs, dimensions/SHA/source closure OK"
    exit 0
}
finally {
    Pop-Location
}

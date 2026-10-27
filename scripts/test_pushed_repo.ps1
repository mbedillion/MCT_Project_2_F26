param(
    [Parameter(Mandatory = $true)]
    [string]$RemoteUrl,

    [Parameter(Mandatory = $true)]
    [string]$SolutionPath,

    [string]$WebotsPath = 'C:\Program Files\Webots\msys64\mingw64\bin\webots.exe',
    [int]$TimeoutSeconds = 600,
    [switch]$KeepClone
)

$ErrorActionPreference = 'Stop'
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $tempRoot ("MCT-F26-Project2-acceptance-" + [guid]::NewGuid())
$clonePath = Join-Path $testRoot 'repo'
$stdoutPath = Join-Path $testRoot 'webots.stdout.log'
$stderrPath = Join-Path $testRoot 'webots.stderr.log'
$runtimePath = Join-Path $testRoot 'runtime'
$webotsProcess = $null

function Invoke-Git {
    param([string[]]$Arguments)
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & git @Arguments 2>&1
    $ErrorActionPreference = $savedPreference
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$output"
    }
    return $output
}

try {
    if (-not (Test-Path -LiteralPath $SolutionPath -PathType Leaf)) {
        throw "Solution file not found: $SolutionPath"
    }
    if (-not (Test-Path -LiteralPath $WebotsPath -PathType Leaf)) {
        throw "Webots executable not found: $WebotsPath"
    }

    New-Item -ItemType Directory -Path $testRoot, $runtimePath | Out-Null
    Invoke-Git @('clone', '--no-local', $RemoteUrl, $clonePath) | Out-Host
    $commit = (Invoke-Git @('-C', $clonePath, 'rev-parse', 'HEAD')).Trim()

    $objects = Invoke-Git @('-C', $clonePath, 'rev-list', '--objects', '--all')
    $forbiddenNames = $objects | Select-String -Pattern '(?i)(solution|_sol\.|Solutions\.mlx|controller_results|simulation_proof|\.zip$)'
    if ($forbiddenNames) {
        throw "Reachable history contains forbidden solution/result paths:`n$forbiddenNames"
    }

    $solutionBlob = (Invoke-Git @('hash-object', $SolutionPath)).Trim()
    if ($objects | Select-String -SimpleMatch $solutionBlob) {
        throw 'The exact local solution blob is reachable from the pushed history.'
    }

    $implementationMarkers = @(
        ('K = pl' + 'ace(A, B, [-10, -8, -3, -1])'),
        ('desired' + 'Velocity = 6')
    )
    $commits = Invoke-Git @('-C', $clonePath, 'rev-list', '--all')
    foreach ($candidateCommit in $commits) {
        foreach ($marker in $implementationMarkers) {
            $matches = & git -C $clonePath grep -F -- $marker $candidateCommit -- 2>$null
            if ($LASTEXITCODE -eq 0 -and $matches) {
                throw "Solution implementation marker is reachable in commit ${candidateCommit}: $marker"
            }
        }
    }

    $activeController = Join-Path $clonePath 'controllers\main_matlab\your_controller.m'
    $proofPath = Join-Path $clonePath 'controllers\main_matlab\simulation_proof.log'
    $studentText = Get-Content -LiteralPath $activeController -Raw
    if ($studentText -notmatch 'Safe placeholder' -or $studentText -match 'K\s*=\s*place') {
        throw 'The pushed active controller is not the safe student template.'
    }

    Copy-Item -LiteralPath $SolutionPath -Destination $activeController -Force
    $worldPath = Join-Path $clonePath 'worlds\automotive_new.wbt'
    $previousTemp = $env:TEMP
    $previousTmp = $env:TMP
    $previousTuning = $env:MATLAB_TUNING
    $env:TEMP = $runtimePath
    $env:TMP = $runtimePath
    $env:MATLAB_TUNING = '1'

    $arguments = @('--mode=fast', '--stdout', '--stderr', $worldPath)
    $webotsProcess = Start-Process -FilePath $WebotsPath -ArgumentList $arguments `
        -WorkingDirectory $clonePath -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath -PassThru

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $passed = $false
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Seconds 2
        $combined = ''
        if (Test-Path -LiteralPath $stdoutPath) {
            $combined += Get-Content -LiteralPath $stdoutPath -Raw
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $combined += Get-Content -LiteralPath $stderrPath -Raw
        }
        if (Test-Path -LiteralPath $proofPath) {
            $combined += Get-Content -LiteralPath $proofPath -Raw
        }
        if ($combined -match 'Destination reached!' -and
            $combined -match 'Grade: 100\.00/100\.0') {
            $passed = $true
            break
        }
        if ($webotsProcess.HasExited) {
            break
        }
    }

    $combined = ''
    if (Test-Path -LiteralPath $stdoutPath) {
        $combined += Get-Content -LiteralPath $stdoutPath -Raw
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $combined += Get-Content -LiteralPath $stderrPath -Raw
    }
    if (Test-Path -LiteralPath $proofPath) {
        $combined += Get-Content -LiteralPath $proofPath -Raw
    }
    if (-not $passed) {
        throw "Remote acceptance test did not reach the exact 100.00/100.0 result.`n$combined"
    }

    $gradeLine = ($combined -split "`r?`n" | Where-Object { $_ -match '^Grade:' } | Select-Object -Last 1)
    Write-Output "Remote acceptance passed at commit $commit"
    Write-Output $gradeLine
}
finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    $env:MATLAB_TUNING = $previousTuning

    if ($webotsProcess -and -not $webotsProcess.HasExited) {
        & taskkill.exe /PID $webotsProcess.Id /T /F 2>$null | Out-Null
        Start-Sleep -Seconds 3
    }

    if (-not $KeepClone -and (Test-Path -LiteralPath $testRoot)) {
        $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
        if (-not $resolvedTestRoot.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove test directory outside system temp: $resolvedTestRoot"
        }
        $removed = $false
        for ($attempt = 1; $attempt -le 10 -and -not $removed; $attempt++) {
            try {
                Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
                $removed = $true
            } catch {
                if ($attempt -eq 10) {
                    throw
                }
                Start-Sleep -Seconds 2
            }
        }
    } elseif ($KeepClone) {
        Write-Output "Acceptance clone retained at: $testRoot"
    }
}

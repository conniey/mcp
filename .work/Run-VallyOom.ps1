#Requires -Version 7

[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$EvalSpec = '.work\vally\evals\managedlustre\eval.yaml',
    [ValidateRange(1, 32)]
    [int]$Workers = 1
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
if (![System.IO.Path]::IsPathRooted($EvalSpec)) {
    $EvalSpec = Join-Path $RepoRoot $EvalSpec
}
$EvalSpec = (Resolve-Path -LiteralPath $EvalSpec).Path
$evalInstructions = Join-Path $RepoRoot 'eng\tools\VallyEvaluator\src\Resources\eval.instructions.md'
if (!(Test-Path -LiteralPath $evalInstructions -PathType Leaf)) {
    throw "Evaluation instructions not found: $evalInstructions"
}
Get-Command node, vally -ErrorAction Stop | Out-Null

$runDirectory = Join-Path $RepoRoot ('.work\oom\' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))
$dumpDirectory = Join-Path $runDirectory 'dumps'
New-Item -ItemType Directory -Path $dumpDirectory -Force | Out-Null
$agentsFile = Join-Path $RepoRoot 'AGENTS.md'
$copilotFile = Join-Path $RepoRoot '.github\copilot-instructions.md'
$agentsBackup = Join-Path $runDirectory 'AGENTS.original.md'
$copilotBackup = Join-Path $runDirectory 'copilot-instructions.original.md'
$agentsMoved = $false
$copilotMoved = $false
$agentsInstalled = $false
$previousNodeOptions = $env:NODE_OPTIONS
$exitCode = 1

try {
    # Node parses backslashes as escapes inside quoted NODE_OPTIONS values.
    $escapedDumpDirectory = $dumpDirectory.Replace('\', '\\')
    # Replace conflicting inherited heap flags so the reproduction retains its 4 GiB ceiling.
    $env:NODE_OPTIONS = '--max-old-space-size=4096 --heapsnapshot-near-heap-limit=1 ' +
        '--report-on-fatalerror --report-uncaught-exception ' +
        "--diagnostic-dir=`"$escapedDumpDirectory`" --report-directory=`"$escapedDumpDirectory`""
    Write-Host "Diagnostics: $runDirectory"
    Write-Host "NODE_OPTIONS: $env:NODE_OPTIONS"
    Write-Warning 'Heap snapshots need several GB of disk space and may contain secrets. Do not run another eval against this repository concurrently.'

    & node -e 'console.log("Node diagnostic options accepted; heap limit:", require("v8").getHeapStatistics().heap_size_limit)'
    if ($LASTEXITCODE -ne 0) {
        throw 'Node rejected the diagnostic options.'
    }

    if (Test-Path -LiteralPath $agentsFile) {
        Move-Item -LiteralPath $agentsFile -Destination $agentsBackup
        $agentsMoved = $true
    }
    if (Test-Path -LiteralPath $copilotFile) {
        Move-Item -LiteralPath $copilotFile -Destination $copilotBackup
        $copilotMoved = $true
    }
    Copy-Item -LiteralPath $evalInstructions -Destination $agentsFile
    $agentsInstalled = $true

    Push-Location -LiteralPath $RepoRoot
    try {
        # Snapshot writing can exceed the default two-minute session timeout.
        & vally eval --eval-spec $EvalSpec --work-dir $RepoRoot `
            --param AGENT_ENVIRONMENT=azmcp_windows `
            --workers $Workers --max-retries 0 --timeout 10m --verbose `
            --output-dir (Join-Path $runDirectory 'results') `
            2>&1 | Tee-Object -FilePath (Join-Path $runDirectory 'vally.log')
        $exitCode = $LASTEXITCODE
        Set-Content -LiteralPath (Join-Path $runDirectory 'exit-code.txt') -Value $exitCode
    } finally {
        Pop-Location
    }
} finally {
    try {
        if ($agentsMoved) {
            Move-Item -LiteralPath $agentsBackup -Destination $agentsFile -Force
        } elseif ($agentsInstalled) {
            Remove-Item -LiteralPath $agentsFile
        }
    } finally {
        try {
            if ($copilotMoved) {
                Move-Item -LiteralPath $copilotBackup -Destination $copilotFile -Force
            }
        } finally {
            $env:NODE_OPTIONS = $previousNodeOptions
        }
    }
}

Write-Host "Vally exit code: $exitCode. Results, log, and dumps: $runDirectory"
exit $exitCode

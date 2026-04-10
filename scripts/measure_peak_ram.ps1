param(
    [Parameter(Mandatory = $true)]
    [string]$Algorithm,

    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [double]$MinSup,

    [string]$OutputPath = "output",
    [string]$JuliaPath = "julia",
    [int]$PollIntervalMs = 50,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Format-MB([Int64]$Bytes) {
    return [Math]::Round(($Bytes / 1MB), 2)
}

function Update-Peak([Int64]$CurrentPeak, [Int64]$Candidate) {
    if ($Candidate -gt $CurrentPeak) {
        return $Candidate
    }

    return $CurrentPeak
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$mainScript = Join-Path $repoRoot "src/main.jl"

if (-not (Test-Path -LiteralPath $mainScript)) {
    throw "Cannot find Julia entry point: $mainScript"
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input file not found: $InputPath"
}

$minSupText = $MinSup.ToString([System.Globalization.CultureInfo]::InvariantCulture)
$argumentList = @(
    $mainScript
    "-a"
    $Algorithm
    $InputPath
    $OutputPath
    $minSupText
)

$peakWorkingSet = 0L
$peakPrivateMemory = 0L
$peakPagedMemory = 0L
$samples = 0

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$process = Start-Process -FilePath $JuliaPath -ArgumentList $argumentList -PassThru -NoNewWindow

try {
    while (-not $process.HasExited) {
        $process.Refresh()
        $peakWorkingSet = Update-Peak $peakWorkingSet $process.WorkingSet64
        $peakPrivateMemory = Update-Peak $peakPrivateMemory $process.PrivateMemorySize64
        $peakPagedMemory = Update-Peak $peakPagedMemory $process.PagedMemorySize64
        $samples += 1

        Start-Sleep -Milliseconds $PollIntervalMs
    }

    $process.WaitForExit()
    $process.Refresh()
}
finally {
    $stopwatch.Stop()
}

$peakWorkingSet = Update-Peak $peakWorkingSet $process.PeakWorkingSet64
$peakPrivateMemory = Update-Peak $peakPrivateMemory $process.PrivateMemorySize64
$peakPagedMemory = Update-Peak $peakPagedMemory $process.PagedMemorySize64

$result = [PSCustomObject]@{
    algorithm = $Algorithm
    input_file = $InputPath
    minsup = $minSupText
    output_path = $OutputPath
    julia_path = $JuliaPath
    runtime_ms = [Math]::Round($stopwatch.Elapsed.TotalMilliseconds, 2)
    exit_code = $process.ExitCode
    poll_interval_ms = $PollIntervalMs
    samples = $samples
    peak_working_set_bytes = $peakWorkingSet
    peak_working_set_mb = Format-MB $peakWorkingSet
    peak_private_bytes = $peakPrivateMemory
    peak_private_mb = Format-MB $peakPrivateMemory
    peak_paged_bytes = $peakPagedMemory
    peak_paged_mb = Format-MB $peakPagedMemory
}

if ($Json) {
    $result | ConvertTo-Json -Depth 3
}
else {
    Write-Host ("Algorithm           : {0}" -f $result.algorithm)
    Write-Host ("Input file          : {0}" -f $result.input_file)
    Write-Host ("Minimum support     : {0}" -f $result.minsup)
    Write-Host ("Exit code           : {0}" -f $result.exit_code)
    Write-Host ("Runtime (ms)        : {0}" -f $result.runtime_ms)
    Write-Host ("Peak RAM (MB)       : {0}" -f $result.peak_working_set_mb)
    Write-Host ("Peak private (MB)   : {0}" -f $result.peak_private_mb)
    Write-Host ("Peak paged (MB)     : {0}" -f $result.peak_paged_mb)
    Write-Host ("Polling interval ms : {0}" -f $result.poll_interval_ms)
    Write-Host ("Samples             : {0}" -f $result.samples)
}

exit $process.ExitCode

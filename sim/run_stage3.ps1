param(
    [string]$QuartusRoot = 'F:/altera/quartus',
    [string]$QuestaBin = 'C:/questasim64_2024.1/win64',
    [int]$Seed = 20260909
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$project = Join-Path $repo 'quartus/stage2'
$run = Join-Path $PSScriptRoot ('stage3_runs/' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Path $run | Out-Null

# Stage 3 orchestration

function Invoke-Logged([string]$Exe, [string[]]$ToolArgs, [string]$Log) {
    Write-Host ("Running " + [IO.Path]::GetFileName($Exe) + ' ' + ($ToolArgs -join ' '))
    & $Exe @ToolArgs 2>&1 | Tee-Object -FilePath $Log
    if ($LASTEXITCODE -ne 0) { throw "Tool failed: $Exe. See $Log" }
}

function Get-InputManifest {
    $paths = @(Get-ChildItem (Join-Path $repo 'src/keccak_engine') -File -Filter '*.sv')
    $paths += @(Get-ChildItem (Join-Path $repo 'tb_uvm/tb_uvm_keccak_v2') -File -Filter '*.sv')
    $paths += @(Get-ChildItem $project -File | Where-Object { $_.Extension -in '.qpf','.qsf','.sdc','.sv' })
    $paths += Get-Item (Join-Path $PSScriptRoot 'run_stage2.do'), $PSCommandPath
    @($paths | Sort-Object FullName | ForEach-Object {
        [ordered]@{
            Path = $_.FullName.Substring($repo.Length + 1)
            SHA256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
        }
    })
}

$inputs = Get-InputManifest
$manifest = [ordered]@{
    Started = (Get-Date).ToString('o')
    Seed = $Seed
    Top = 'keccak_synth_top'
    Scope = 'One fitted core; only UVM lane 0 driven; 125 port-only transactions'
    GitHead = (& git -C $repo rev-parse HEAD)
    GitBranch = (& git -C $repo branch --show-current)
    GitStatus = @(& git -C $repo status --short)
    Inputs = $inputs
    Status = 'RUNNING'
    QuartusRoot = $QuartusRoot
    QuestaBin = $QuestaBin
}
$manifestPath = Join-Path $run 'manifest.json'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath

$envNames = 'KECCAK_REPO','KECCAK_SEED','KECCAK_NETLIST','KECCAK_REPRESENTATION','KECCAK_UCDB','QUARTUS_ROOTDIR'
$savedEnv = @{}
foreach ($name in $envNames) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

try {
    Push-Location $project
    try {
        Invoke-Logged (Join-Path $QuartusRoot 'bin64/quartus_map.exe') @(
            'keccak_stage2','--read_settings_files=on','--write_settings_files=off'
        ) (Join-Path $run 'synthesis.log')
        Invoke-Logged (Join-Path $QuartusRoot 'bin64/quartus_fit.exe') @(
            'keccak_stage2','--read_settings_files=on','--write_settings_files=off'
        ) (Join-Path $run 'fitter.log')
        Invoke-Logged (Join-Path $QuartusRoot 'bin64/quartus_sta.exe') @(
            'keccak_stage2'
        ) (Join-Path $run 'timing.log')
        Invoke-Logged (Join-Path $QuartusRoot 'bin64/quartus_eda.exe') @(
            'keccak_stage2','--simulation=on','--functional=on','--tool=questasim',
            '--format=verilog','--output_directory=simulation_postfit',
            '--read_settings_files=on','--write_settings_files=off'
        ) (Join-Path $run 'netlist.log')

        $staSummary = Get-Content -LiteralPath (Join-Path $project 'output_files/keccak_stage2.sta.summary') -Raw
        $staReport = Get-Content -LiteralPath (Join-Path $project 'output_files/keccak_stage2.sta.rpt') -Raw
        $slacks = @([regex]::Matches($staSummary, 'Slack\s*:\s*(-?\d+(?:\.\d+)?)') |
            ForEach-Object { [double]$_.Groups[1].Value })
        if ($slacks.Count -eq 0 -or ($slacks | Measure-Object -Minimum).Minimum -lt 0) {
            throw 'Post-fit TimeQuest contains a negative or missing slack result'
        }
        if ($staReport -notmatch 'Design is fully constrained for setup requirements' -or
            $staReport -notmatch 'Design is fully constrained for hold requirements') {
            throw 'Post-fit TimeQuest did not report fully constrained setup and hold paths'
        }
        $manifest.PostFitTiming = 'MET_50_MHZ'
        $manifest.WorstSlackNs = ($slacks | Measure-Object -Minimum).Minimum
    } finally {
        Pop-Location
    }

    Copy-Item -LiteralPath (Join-Path $project 'simulation_postfit/keccak_stage2.vo') -Destination $run
    Copy-Item -Path (Join-Path $project 'output_files/*.rpt') -Destination $run
    Copy-Item -Path (Join-Path $project 'output_files/*.summary') -Destination $run

    $env:KECCAK_REPO = $repo
    $env:KECCAK_SEED = "$Seed"
    $env:QUARTUS_ROOTDIR = $QuartusRoot
    $env:KECCAK_NETLIST = Join-Path $run 'keccak_stage2.vo'
    $env:KECCAK_UCDB = 'stage3.ucdb'
    $manifest.PostFitNetlistSHA256 = (Get-FileHash $env:KECCAK_NETLIST -Algorithm SHA256).Hash

    foreach ($runKind in 'rtl','postfit') {
        $dir = Join-Path $run $runKind
        New-Item -ItemType Directory -Path $dir | Out-Null
        $env:KECCAK_REPRESENTATION = if ($runKind -eq 'rtl') { 'rtl' } else { 'netlist' }
        $doFile = (Join-Path $PSScriptRoot 'run_stage2.do').Replace('\','/')
        Push-Location $dir
        try {
            Invoke-Logged (Join-Path $QuestaBin 'vsim.exe') @(
                '-c','-do',('do {' + $doFile + '}')
            ) (Join-Path $dir 'console.log')
            $transcript = Get-Content -LiteralPath 'transcript' -Raw
            if ($transcript -notmatch 'STAGE2_SUITE_COMPLETE 125 checked transactions' -or
                $transcript -match '(?m)^# \*\* (Error|Fatal)\b' -or
                $transcript -match '(?m)^# UVM_(ERROR|FATAL)(?:[ \t]+@|[ \t]*:[ \t]*[1-9])') {
                throw "Failed or incomplete $runKind simulation. See $dir"
            }
            $lines = @(Get-Content -LiteralPath 'checked_transactions.txt')
            if ($lines.Count -ne 125) {
                throw "Expected 125 checked records, got $($lines.Count)"
            }
            Invoke-Logged (Join-Path $QuestaBin 'vcover.exe') @(
                'report','-summary','stage3.ucdb'
            ) (Join-Path $dir 'coverage_summary.txt')
        } finally {
            Pop-Location
        }
    }

    $rtlHash = (Get-FileHash (Join-Path $run 'rtl/checked_transactions.txt')).Hash
    $postFitHash = (Get-FileHash (Join-Path $run 'postfit/checked_transactions.txt')).Hash
    if ($rtlHash -ne $postFitHash) {
        throw 'Source/post-fit checked transaction records differ'
    }
    if (($inputs | ConvertTo-Json -Depth 6 -Compress) -ne
        ((Get-InputManifest) | ConvertTo-Json -Depth 6 -Compress)) {
        throw 'Source files changed during the run; rerun for consistent evidence'
    }

    $manifest.Status = 'POST_FIT_FUNCTIONAL_COMPARISON_PASS'
    $manifest.CheckedTransactions = 125
    $manifest.TransactionRecordSHA256 = $rtlHash
    Write-Host 'PASS: source RTL and post-fit netlist matched all 125 checked transactions.'
} catch {
    $manifest.Status = 'FAIL'
    $manifest.Failure = $_.Exception.Message
    throw
} finally {
    $manifest.Completed = (Get-Date).ToString('o')
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath
    foreach ($name in $envNames) {
        [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], 'Process')
    }
    Write-Host "Evidence: $run"
}

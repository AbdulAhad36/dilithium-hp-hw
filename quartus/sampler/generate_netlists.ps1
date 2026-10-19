param([string]$QuartusBin = 'F:\altera\quartus\bin64')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (!(Test-Path 'output_files/sampler.fit.summary')) { throw 'Compile sampler.qpf first.' }
    & "$QuartusBin\quartus_eda.exe" sampler --simulation --functional=off --tool=questasim --format=verilog --output_directory=simulation_postfit --write_settings_files=off *> stage5_postfit_eda.log
    if ($LASTEXITCODE -ne 0) { throw 'Post-fit export failed; see stage5_postfit_eda.log.' }
    $synthDir = Join-Path $PSScriptRoot 'postsynth_build'
    New-Item -ItemType Directory -Path $synthDir -Force | Out-Null
    if (Test-Path (Join-Path $synthDir 'output_files/sampler.fit.summary')) { throw 'Synthesis-only helper contains a fitted database.' }
    $qsf = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'sampler.qsf'))
    [System.IO.File]::WriteAllText((Join-Path $synthDir 'sampler.qsf'), $qsf.Replace('../../src/', '../../../src/'))
    Copy-Item -LiteralPath 'sampler.qpf','sampler.sdc' -Destination $synthDir -Force
    Push-Location $synthDir
    try {
        & "$QuartusBin\quartus_map.exe" sampler *> ../stage5_postsynth_map.log
        if ($LASTEXITCODE -ne 0) { throw 'Synthesis failed; see stage5_postsynth_map.log.' }
        & "$QuartusBin\quartus_eda.exe" sampler --simulation --functional=on --tool=questasim --format=verilog --output_directory=../simulation_postsynth --write_settings_files=off *> ../stage5_postsynth_eda.log
        if ($LASTEXITCODE -ne 0) { throw 'Synthesis export failed; see stage5_postsynth_eda.log.' }
    } finally { Pop-Location }
    Write-Host 'SAMPLER NETLIST EXPORT COMPLETE: synthesis-only helper and active fitted database.'
} finally { Pop-Location }

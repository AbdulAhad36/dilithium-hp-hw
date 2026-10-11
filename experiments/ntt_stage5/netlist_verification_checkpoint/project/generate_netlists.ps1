# Export distinct post-synthesis and post-fit functional netlists.
param([string]$QuartusBin = 'F:\altera\quartus\bin64')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (!(Test-Path 'output_files/ntt.fit.summary')) { throw 'Build the main project first.' }
    # Standard Edition can select the fitted database even with a synthesized
    # snapshot argument. Export final here; synthesize separately without a fit.
    & "$QuartusBin\quartus_eda.exe" ntt -c ntt --simulation --functional=off --tool=modelsim --format=verilog --output_directory=simulation_postfit --write_settings_files=off *> stage5_postfit_eda.log
    if ($LASTEXITCODE -ne 0) { throw 'Post-fit export failed; see stage5_postfit_eda.log' }
    $synthDir = Join-Path $PSScriptRoot 'postsynth_build'
    New-Item -ItemType Directory -Path $synthDir -Force | Out-Null
    if (Test-Path (Join-Path $synthDir 'output_files/ntt.fit.summary')) { throw 'Synthesis-only helper contains a fitted database; use a fresh helper directory.' }
    $qsf = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ntt.qsf'))
    [System.IO.File]::WriteAllText((Join-Path $synthDir 'ntt.qsf'), $qsf.Replace('../../src/','../../../src/'))
    Copy-Item -LiteralPath 'ntt.qpf','ntt.sdc' -Destination $synthDir -Force
    Push-Location $synthDir
    try {
        & "$QuartusBin\quartus_map.exe" ntt -c ntt *> ../stage5_postsynth_map.log
        if ($LASTEXITCODE -ne 0) { throw 'Synthesis-only map failed; see stage5_postsynth_map.log' }
        & "$QuartusBin\quartus_eda.exe" ntt -c ntt --simulation --functional=on --tool=modelsim --format=verilog --output_directory=../simulation_postsynth --write_settings_files=off *> ../stage5_postsynth_eda.log
        if ($LASTEXITCODE -ne 0) { throw 'Post-synthesis export failed; see stage5_postsynth_eda.log' }
    } finally { Pop-Location }
    Write-Host 'NTT_NETLIST_EXPORT_COMPLETE: synthesis-only helper and active fitted project.'
} finally { Pop-Location }

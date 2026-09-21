param(
    [string]$Ucdb = (Join-Path $PSScriptRoot 'keccak_dual_coverage.ucdb'),
    [int]$Lane = 0,
    [string]$Vcover = 'C:\questasim64_2024.1\win64\vcover.exe'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Ucdb)) {
    throw "Coverage database not found: $Ucdb"
}

if (-not (Test-Path -LiteralPath $Vcover)) {
    throw "Questa vcover executable not found: $Vcover"
}

$laneScope = "/tb_top/u_uvm_core/g_lane[$Lane]/u_core"

Write-Host "`n=== Functional coverage: implemented covergroup ===" -ForegroundColor Cyan
& $Vcover report -cvg -summary $Ucdb
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`n=== RTL code coverage: complete lane $Lane hierarchy ===" -ForegroundColor Cyan
& $Vcover report "-instance=$laneScope" -code bcesft $Ucdb
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`nFunctional covergroups and RTL code metrics are separate reports."

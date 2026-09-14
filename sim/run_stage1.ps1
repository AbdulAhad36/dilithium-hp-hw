param(
    [string]$QuestaBin = 'C:\questasim64_2024.1\win64',
    [switch]$Gui
)

$ErrorActionPreference = 'Stop'

$vsim = Join-Path $QuestaBin 'vsim.exe'
if (-not (Test-Path -LiteralPath $vsim)) {
    throw "Questa vsim executable not found: $vsim"
}

$runDo = Join-Path $PSScriptRoot 'run.do'
$existingKernelIds = @(Get-Process -Name 'vsimk' -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Id)
$arguments = if ($Gui) {
    @('-do', "do {$runDo}")
} else {
    @('-c', '-do', "do {$runDo}; quit - -force")
}

Push-Location $PSScriptRoot
try {
    & $vsim @arguments
    $launcherExit = $LASTEXITCODE
    if ($launcherExit -ne 0) {
        exit $launcherExit
    }

    if (-not $Gui) {
        # On Windows, vsim.exe can return after spawning the simulation kernel.
        # Wait for the kernel created by this run before inspecting evidence.
        $newKernels = @(Get-Process -Name 'vsimk' -ErrorAction SilentlyContinue |
            Where-Object { $_.Id -notin $existingKernelIds })
        if ($newKernels.Count -gt 0) {
            $newKernels | Wait-Process
        }

        $transcript = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'transcript') -Raw
        if ($transcript -notmatch '100\.00% \(888 passed samples\)' -or
            $transcript -match '(?m)^# \*\* (Error|Fatal)\b' -or
            $transcript -match '(?m)^# UVM_(ERROR|FATAL)[ \t]*:[ \t]*[1-9]') {
            throw 'Stage 1 failed or did not complete all 888 checked transactions'
        }
    }

    exit 0
} finally {
    Pop-Location
}

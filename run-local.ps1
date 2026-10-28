param(
    [ValidateSet('env', 'winograd', 'cordic', 'fsm', 'all')]
    [string]$Task = 'env'
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$toolBin = Join-Path $projectRoot '.tools\iverilog\mingw64\bin'
$iverilog = Join-Path $toolBin 'iverilog.exe'
$vvp = Join-Path $toolBin 'vvp.exe'
if (!(Test-Path -LiteralPath $iverilog) -or !(Test-Path -LiteralPath $vvp)) {
    throw 'The project-local Icarus Verilog toolchain is missing.'
}

$oldPath = $env:PATH
$env:PATH = "$toolBin;C:\msys64\mingw64\bin;$oldPath"
$taskNames = if ($Task -eq 'all') { @('winograd', 'cordic', 'fsm') } else { @($Task) }

try {
    foreach ($taskName in $taskNames) {
        $buildDir = Join-Path $projectRoot "build\$taskName"
        New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
        $output = Join-Path $buildDir 'sim.vvp'
        $compileLog = Join-Path $buildDir 'compile.log'
        $simulationLog = Join-Path $buildDir 'simulation.log'

        if ($taskName -eq 'env') {
            $sourceDir = $projectRoot
            $compilerArgs = @('-g2012', '-s', 'env_check', '-o', $output,
                '.tools/checks/env_check.sv')
            $successMarker = 'ENV_CHECK_PASS'
        } else {
            $top = switch ($taskName) {
                'winograd' { 'winograd_1d_tb' }
                'cordic' { 'cordic_tb' }
                'fsm' { 'double_buffer_ctrl_tb' }
            }
            $sourceDir = Join-Path $projectRoot "lab1_files\$taskName\run"
            $waveWrapper = Join-Path $buildDir 'local_wave_dump.sv'
            @"
module local_wave_dump;
    initial begin
        `$dumpfile("wave.vcd");
        `$dumpvars(0, $top);
    end
endmodule
"@ | Set-Content -LiteralPath $waveWrapper -Encoding Ascii
            $compilerArgs = @('-g2012', '-DNO_FSDB', '-s', $top,
                '-s', 'local_wave_dump', '-c', "$taskName.f", '-o', $output, $waveWrapper)
            $successMarker = 'ALL PASS'
        }

        Write-Host "Compiling $taskName ..."
        Push-Location -LiteralPath $sourceDir
        try {
            & $iverilog @compilerArgs *> $compileLog
            $compileExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        Get-Content -LiteralPath $compileLog
        if ($compileExit -ne 0) {
            throw "Compilation failed for $taskName. See $compileLog"
        }

        Push-Location -LiteralPath $buildDir
        try {
            & $vvp $output *> $simulationLog
            $simulationExit = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        Get-Content -LiteralPath $simulationLog
        if ($simulationExit -ne 0 -or
            !(Select-String -LiteralPath $simulationLog -SimpleMatch $successMarker -Quiet)) {
            throw "Simulation did not pass for $taskName. See $simulationLog"
        }
        Write-Host "PASS: $taskName"
    }
} finally {
    $env:PATH = $oldPath
}

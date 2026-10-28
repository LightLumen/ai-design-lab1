param()

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
$buildDir = Join-Path $projectRoot 'build\cordic'
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

function Invoke-LoggedTool {
    param([string]$Executable, [string[]]$Arguments, [string]$LogPath)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        Set-Content -LiteralPath $LogPath -Value '' -Encoding UTF8
        & $Executable @Arguments 2>&1 | ForEach-Object { "$_" } |
            Set-Content -LiteralPath $LogPath -Encoding UTF8
        $toolExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    Get-Content -LiteralPath $LogPath
    if ($toolExit -ne 0) {
        throw "Tool failed with exit code ${toolExit}: $LogPath"
    }
}

# Keep the supplied file list, testbench and run-local.ps1 unchanged.
$checks = @(
    @{ Name = 'public'; Top = 'cordic_tb';
       Testbench = 'lab1_files/cordic/src/cordic_tb.sv';
       Marker = 'ALL PASS: CORDIC, 10 cases' },
    @{ Name = 'selfcheck'; Top = 'cordic_selfcheck_tb';
       Testbench = 'lab1_files/cordic/verification/cordic_selfcheck_tb.sv';
       Marker = 'ALL PASS: CORDIC selfcheck' }
)
Push-Location -LiteralPath $projectRoot
try {
    foreach ($check in $checks) {
        $name = $check.Name
        $output = "build/cordic/$name.vvp"
        $compileLog = Join-Path $buildDir "$name.compile.log"
        $simulationLog = Join-Path $buildDir "$name.simulation.log"
        $compilerArgs = @('-g2012', '-Wall', '-DNO_FSDB', '-s', $check.Top,
                          '-o', $output)
        if ($name -eq 'public') { $compilerArgs += @('-s', 'cordic_wave_dump') }
        $compilerArgs += @('lab1_files/cordic/src/cordic.v', $check.Testbench)
        if ($name -eq 'public') {
            $compilerArgs += @('lab1_files/cordic/verification/cordic_wave_dump.sv')
        }
        Write-Host "Compiling $name ..."
        Invoke-LoggedTool -Executable $iverilog -Arguments $compilerArgs -LogPath $compileLog
        Invoke-LoggedTool -Executable $vvp -Arguments @($output) -LogPath $simulationLog
        if (!(Select-String -LiteralPath $simulationLog -SimpleMatch $check.Marker -Quiet)) {
            throw "Success marker missing: $simulationLog"
        }
        Write-Host "PASS: $name"
    }
} finally {
    Pop-Location
    $env:PATH = $oldPath
}

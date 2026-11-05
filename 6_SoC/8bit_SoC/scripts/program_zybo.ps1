# Program the Zybo Z7-20 PL with the 8bit SoC bitstream (Windows, Vivado
# Hardware Manager in batch mode, scripts/program_zybo.tcl).
# Usage (PowerShell):
#   powershell -ExecutionPolicy Bypass -File <repo>\6_SoC\8bit_SoC\scripts\program_zybo.ps1 [-Bit <file.bit>] [-VivadoBin <dir>]
#   -Bit        default: the WSL build folder outside the repository
#               (build it in WSL: bash 6_SoC/8bit_SoC/scripts/build_zybo.sh /home/sean/zybo_build)
#   -VivadoBin  default: C:\Xilinx\Vivado\2024.2\bin
# Vivado runs in a local temporary folder (cmd.exe cannot use a UNC path as
# its working folder). Exit status 0 only if the log has SOC8_ZYBO_PROGRAM_PASS.
param(
    [string]$Bit = '\\wsl.localhost\Ubuntu-22.04\home\sean\zybo_build\soc8_zybo_top.bit',
    [string]$VivadoBin = 'C:\Xilinx\Vivado\2024.2\bin'
)
$ErrorActionPreference = 'Stop'
$tcl = Join-Path $PSScriptRoot 'program_zybo.tcl'
$vivado = Join-Path $VivadoBin 'vivado.bat'
if (-not (Test-Path -LiteralPath $vivado)) { throw "Vivado not found: $vivado" }
if (-not (Test-Path -LiteralPath $Bit)) { throw "Bitstream not found: $Bit" }
$work = Join-Path $env:TEMP 'soc8_zybo_program'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$log = Join-Path $work 'program.log'
Push-Location -LiteralPath $work
try {
    # Vivado's stderr lines become error records in PowerShell 5.1; keep running and log them as text.
    $ErrorActionPreference = 'Continue'
    & $vivado -mode batch -nojournal -nolog -notrace -source ($tcl -replace '\\', '/') -tclargs ($Bit -replace '\\', '/') 2>&1 |
        ForEach-Object { "$_" } | Tee-Object -FilePath $log
} finally {
    $ErrorActionPreference = 'Stop'
    Pop-Location
}
$pass = Select-String -LiteralPath $log -Pattern '^SOC8_ZYBO_PROGRAM_PASS' -Quiet
if ($pass) { Write-Output "RESULT status=0 log=$log"; exit 0 }
Write-Output "RESULT status=1 log=$log"
exit 1
